require "json"

class DeliveryNotesController < ApplicationController
  include EmailPreviewHelper
  include ApplicationHelper
  include PublishableDocument
  include DocumentWithLines

  publishable_document :delivery_note, label: "delivery note"
  document_with_lines line_class: DeliveryNoteLine

  before_action -> { require_permission!("delivery_notes.view") }, only: %i[index show preview preview_email preview_email_raw pdf]
  before_action -> { require_permission!("delivery_notes.edit") }, only: %i[
    new create edit update destroy
    publish unpublish send_email upload_acceptance delete_acceptance
    convert_to_invoice bulk_send_emails
  ]

  before_action :set_delivery_note, only: %i[show edit update destroy publish preview pdf unpublish upload_acceptance delete_acceptance convert_to_invoice preview_email preview_email_raw send_email]

  # Permit the inline <style> blocks and embedded data: images that the
  # mailer layout produces. Scoped strictly to the iframe response so the
  # parent app's strict CSP remains intact.
  content_security_policy(only: :preview_email_raw) do |policy|
    policy.default_src     :none
    policy.style_src       :unsafe_inline
    policy.img_src         :self, :data
    policy.font_src        :none
    policy.script_src      :none
    policy.connect_src     :none
    policy.frame_ancestors :self
  end

  # The global nonce_directives setting auto-injects nonces into script-src
  # and style-src. With both 'unsafe-inline' and a nonce present, the CSP
  # spec tells browsers to ignore 'unsafe-inline' — which would re-block the
  # mailer's inline <style> tags. Strip the nonce list for this action.
  before_action(only: :preview_email_raw) { request.content_security_policy_nonce_directives = [] }
  before_action :require_unpublished, only: %i[edit update publish preview]
  before_action :require_published, only: %i[pdf unpublish upload_acceptance delete_acceptance convert_to_invoice send_email]
  before_action :require_item_line, only: %i[publish preview preview_email]

  # GET /delivery_notes
  def index
    @selected_year = params[:year]&.to_i || Date.current.year
    @email_filter = params[:email_filter] || "all"

    @delivery_notes = DeliveryNote.visible_to(current_user)
                                  .in_year(@selected_year, include_drafts: @selected_year == Date.current.year)
                                  .reorder(Arel.sql("document_number DESC NULLS FIRST"))

    case @email_filter
    when "unsent"
      @delivery_notes = @delivery_notes.email_unsent.published
    end

    @available_years = DeliveryNote.visible_to(current_user).available_years
  end

  # GET /delivery_notes/1
  def show
  end

  # GET /delivery_notes/new
  def new
    @delivery_note = DeliveryNote.new
    set_form_options
  end

  # GET /delivery_notes/1/edit
  def edit
    set_form_options
  end

  # POST /delivery_notes
  def create
    @delivery_note = DeliveryNote.new(delivery_note_params)

    if @delivery_note.save
      redirect_to @delivery_note, notice: "Delivery Note was successfully created."
    else
      render :new, status: :unprocessable_content
    end
  end

  # PUT /delivery_notes/1
  def update
    if @delivery_note.update(delivery_note_params)
      redirect_to @delivery_note, notice: "Delivery Note was successfully updated."
    else
      set_form_options
      render :edit, status: :unprocessable_content
    end
  end

  # DELETE /delivery_notes/1
  def destroy
    if @delivery_note.published?
      flash[:alert] = "Published delivery notes cannot be deleted."
      redirect_to delivery_notes_path and return
    end

    @delivery_note.destroy
    redirect_to delivery_notes_url
  end

  def publish
    begin
      @delivery_note.publish!
      flash[:notice] = "Delivery Note #{@delivery_note.document_number} has been published."
    rescue StandardError => e
      flash[:error] = "Failed to publish delivery note: #{e.message}"
    end

    respond_to do |format|
      format.html { redirect_to @delivery_note }
    end
  end

  def preview
    issuer = IssuerCompany.get_the_issuer!

    @pdf = DeliveryNoteRenderer.new(@delivery_note, issuer).render

    send_data @pdf, type: "application/pdf", disposition: "inline"
  end

  def pdf
    issuer = IssuerCompany.get_the_issuer!

    @pdf = DeliveryNoteRenderer.new(@delivery_note, issuer).render

    filename = "#{issuer.short_name}-DeliveryNote-#{@delivery_note.document_number}.pdf"
    send_data @pdf, type: "application/pdf", disposition: "attachment", filename: filename
  end

  def unpublish
    @delivery_note.update!(published: false, document_number: nil, date: nil)
    flash[:notice] = "Delivery Note has been reverted to draft status."

    respond_to do |format|
      format.html { redirect_to @delivery_note }
    end
  end

  def upload_acceptance
    uploaded_file = params[:acceptance_pdf]

    if uploaded_file.blank?
      flash[:error] = "Please select a PDF file to upload."
      redirect_to @delivery_note and return
    end

    if uploaded_file.size > Attachment::MAX_SIZE_BYTES
      flash[:error] = "Acceptance document is too large (maximum is #{Attachment::MAX_SIZE_BYTES / 1.megabyte} MB)."
      redirect_to @delivery_note and return
    end

    detected_type = Attachment.detect_content_type(uploaded_file.tempfile)
    if detected_type != "application/pdf"
      flash[:error] = "Only PDF files are allowed for acceptance documents (detected: #{detected_type})."
      redirect_to @delivery_note and return
    end

    # If there's an existing acceptance attachment, delete it first
    if @delivery_note.acceptance_attachment.present?
      old_attachment = @delivery_note.acceptance_attachment
      @delivery_note.update!(acceptance_attachment: nil)
      old_attachment.destroy
    end

    # Create new attachment
    attachment = Attachment.new
    attachment.set_data uploaded_file.read, "application/pdf"
    attachment.filename = uploaded_file.original_filename
    attachment.title = "Acceptance Document for Delivery Note #{@delivery_note.document_number}"

    if attachment.save
      @delivery_note.update!(acceptance_attachment: attachment)
      flash[:notice] = "Acceptance document uploaded successfully."
    else
      flash[:error] = "Failed to upload acceptance document: #{attachment.errors.full_messages.join(', ')}"
    end

    respond_to do |format|
      format.html { redirect_to @delivery_note }
    end
  end

  def delete_acceptance
    if @delivery_note.acceptance_attachment.present?
      old_attachment = @delivery_note.acceptance_attachment
      @delivery_note.update!(acceptance_attachment: nil)
      old_attachment.destroy
      flash[:notice] = "Acceptance document deleted successfully."
    else
      flash[:error] = "No acceptance document to delete."
    end

    respond_to do |format|
      format.html { redirect_to @delivery_note }
    end
  end

  def convert_to_invoice
    if @delivery_note.invoice_id.present?
      flash[:error] = "This delivery note has already been converted to an invoice."
      redirect_to @delivery_note and return
    end

    begin
      # Build enhanced prelude with delivery note information
      delivery_note_info = []
      delivery_note_info << "Based on Delivery Note #{@delivery_note.document_number}"
      delivery_note_info << "Delivery Note Date: #{I18n.l(@delivery_note.date)}" if @delivery_note.date
      if @delivery_note.acceptance_attachment
        delivery_note_info << "Acceptance Document: #{@delivery_note.acceptance_attachment.filename} (#{I18n.l(@delivery_note.acceptance_attachment.created_at.to_date)})"
      end

      enhanced_prelude = delivery_note_info.join("\n")
      enhanced_prelude += "\n\n#{@delivery_note.prelude}" if @delivery_note.prelude.present?

      # Create invoice from delivery note
      invoice = Invoice.new(
        customer: @delivery_note.customer,
        project: @delivery_note.project,
        cust_reference: @delivery_note.cust_reference,
        cust_order: @delivery_note.cust_order,
        prelude: enhanced_prelude
      )

      default_sales_tax_product_class_id = SalesTaxProductClass.default&.id

      ActiveRecord::Base.transaction do
        invoice.save!
        # Copy delivery note lines to invoice lines without triggering callbacks that cause issues
        @delivery_note.delivery_note_lines.each do |dn_line|
          # Create invoice line with direct attributes
          attrs = {
            invoice_id: invoice.id,
            type: dn_line.type,
            title: dn_line.title,
            description: dn_line.description,
            position: dn_line.position
          }

          # Set appropriate fields based on line type
          if dn_line.type == "item"
            attrs[:quantity] = (dn_line.quantity&.to_f || 1.0).to_f
            attrs[:rate] = 0.01 # Small non-zero rate
            attrs[:sales_tax_product_class_id] = default_sales_tax_product_class_id
            attrs[:amount] = attrs[:rate] * attrs[:quantity] # Pre-calculate amount
          else
            attrs[:amount] = 0
          end

          # Insert directly to avoid callbacks
          InvoiceLine.create!(attrs)
        end

        # Link the invoice to the delivery note
        @delivery_note.update!(invoice: invoice)

        flash[:notice] = "Invoice draft created successfully from delivery note."
        redirect_to invoice
      end
    rescue StandardError => e
      flash[:error] = "Failed to convert delivery note to invoice: #{e.message}"
      redirect_to @delivery_note
    end
  end

  def preview_email
    mail = DeliveryNoteMailer.with(delivery_note: @delivery_note).customer_email
    render json: extract_email_preview_data(mail)
  end

  def preview_email_raw
    mail = DeliveryNoteMailer.with(delivery_note: @delivery_note, skip_attachments: true).customer_email
    render html: extract_html_body(mail).to_s.html_safe, layout: false
  end

  def send_email
    unless @delivery_note.emailable?
      redirect_to @delivery_note, alert: "No recipient configured for this delivery note." and return
    end
    DeliveryNoteMailer.with(delivery_note: @delivery_note).customer_email.deliver_later
    @delivery_note.update_column(:email_sent_at, Time.current)
    respond_to do |format|
      format.html { redirect_to @delivery_note, notice: "E-Mail queued for sending." }
      format.json { head :ok }
    end
  end

  def bulk_send_emails
    delivery_note_ids = params[:delivery_note_ids] || []
    delivery_note_ids = delivery_note_ids.reject(&:blank?)

    if delivery_note_ids.empty?
      redirect_to delivery_notes_path, alert: "No delivery notes selected."
      return
    end

    delivery_notes = DeliveryNote.visible_to(current_user).where(id: delivery_note_ids, published: true)
    queued_count = 0
    skipped_count = 0
    now = Time.current

    # Partition by [customer_id, resolved-recipient-set]. Two DNs to the same
    # customer with different project-scoped contacts must NOT be combined,
    # otherwise we leak DN A's recipients onto DN B.
    delivery_notes.group_by { |dn| [ dn.customer_id, dn.email_recipients.sort ] }.each do |(_cid, recipients), dns|
      if recipients.empty?
        skipped_count += dns.length
        next
      end

      if dns.length == 1
        DeliveryNoteMailer.with(delivery_note: dns.first).customer_email.deliver_later
      else
        DeliveryNoteMailer.with(delivery_notes: dns, recipients: recipients).bulk_customer_email.deliver_later
      end
      DeliveryNote.where(id: dns.map(&:id)).update_all(email_sent_at: now)
      queued_count += dns.length
    end

    notice = "#{queued_count} emails queued for sending."
    notice += " #{skipped_count} skipped (no recipients)." if skipped_count > 0
    redirect_to delivery_notes_path, notice: notice
  end

protected
  def set_delivery_note
    @delivery_note = DeliveryNote.visible_to(current_user).find(params[:id])
  end

  def delivery_note_params
    params.require(:delivery_note).permit(:customer_id, :project_id, :cust_reference, :cust_order, :prelude, :delivery_start_date, :delivery_end_date,
      delivery_note_lines_attributes: [ :id, :type, :title, :description, :position, :quantity, :_destroy ])
  end
end
