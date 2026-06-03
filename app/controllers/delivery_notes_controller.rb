class DeliveryNotesController < ApplicationController
  include EmailableDocument
  include PublishableDocument
  include DocumentWithLines

  publishable_document :delivery_note, label: "delivery note"
  document_with_lines line_class: DeliveryNoteLine

  before_action -> { require_permission!("delivery_notes.view") }, only: %i[index show preview preview_email preview_email_html pdf]
  before_action -> { require_permission!("delivery_notes.edit") }, only: %i[
    new create edit update destroy
    publish unpublish send_email upload_acceptance delete_acceptance
    convert_to_invoice bulk_send_emails
  ]
  before_action -> { require_permission!("delivery_notes.review_acceptance") }, only: %i[accept_acceptance reject_acceptance]

  before_action :set_delivery_note, only: %i[show edit update destroy publish preview pdf unpublish upload_acceptance delete_acceptance convert_to_invoice preview_email preview_email_html send_email accept_acceptance reject_acceptance]

  before_action :require_unpublished, only: %i[edit update destroy publish preview]
  before_action :require_unnumbered, only: :destroy
  before_action :require_published, only: %i[pdf unpublish upload_acceptance delete_acceptance convert_to_invoice send_email accept_acceptance reject_acceptance]
  before_action :require_item_line, only: %i[preview preview_email]

  # GET /delivery_notes
  def index
    @selected_year = params[:year] == "all" ? "all" : (params[:year]&.to_i || Date.current.year)
    @email_filter = params[:email_filter] || "all"
    @acceptance_filter = params[:acceptance_filter]
    @selected_customer_id = params[:customer_id].presence&.to_i

    @delivery_notes = DeliveryNote.visible_to(current_user).ordered
    unless @selected_year == "all"
      @delivery_notes = @delivery_notes.in_year(@selected_year, include_drafts: @selected_year == Date.current.year)
    end

    case @email_filter
    when "unsent"
      @delivery_notes = @delivery_notes.email_unsent.published
    end

    @delivery_notes = @delivery_notes.with_pending_acceptance.published if @acceptance_filter == "pending"

    @delivery_notes = @delivery_notes.where(customer_id: @selected_customer_id) if @selected_customer_id

    @available_years = DeliveryNote.visible_to(current_user).available_years
    @available_customers = DeliveryNote.available_customers(current_user, including: @selected_customer_id)
  end

  # GET /delivery_notes/1
  def show
  end

  # GET /delivery_notes/new
  def new
    @delivery_note = DeliveryNote.new(customer_id: params[:customer_id].presence)
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
    @delivery_note.destroy
    redirect_to delivery_notes_url
  end

  def publish
    publish_document { @delivery_note.publish! }
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
    # document_number and date are intentionally preserved: numbers come from a
    # gap-free sequence (see require_unnumbered) and the original booking date
    # is part of the audit trail.
    @delivery_note.update!(published: false)
    flash[:notice] = "Delivery Note has been reverted to draft status."

    respond_to do |format|
      format.html { redirect_to @delivery_note }
    end
  end

  def accept_acceptance
    submission = @delivery_note.acceptance_submissions.find(params[:submission_id])
    submission.accept!(by: current_user)
    redirect_to @delivery_note, notice: "Acceptance document confirmed."
  rescue AcceptanceSubmission::StaleSubmission
    redirect_to @delivery_note, alert: "A newer submission arrived — review it before accepting."
  rescue AcceptanceSubmission::AlreadyAccepted
    redirect_to @delivery_note, alert: "This note already has an accepted acceptance document."
  end

  def reject_acceptance
    submission = @delivery_note.acceptance_submissions.find(params[:submission_id])
    submission.reject!(by: current_user)
    redirect_to @delivery_note, notice: "Submission rejected; the upload link is open again."
  rescue AcceptanceSubmission::StaleSubmission
    redirect_to @delivery_note, alert: "That submission is no longer pending."
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
    attachment.title = "Acceptance Document for #{@delivery_note.display_name}"

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
      reference_line = I18n.with_locale(@delivery_note.customer.language.iso_code) do
        I18n.t("invoice_conversion.reference_line",
               number: @delivery_note.display_label,
               date: I18n.l(@delivery_note.date))
      end

      enhanced_prelude = reference_line
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
            # Leave the rate blank: delivery notes carry no prices, and a blank
            # rate blocks publishing until the user enters a real price.
            attrs[:sales_tax_product_class_id] = default_sales_tax_product_class_id
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

    # Partition by [customer_id, resolved-recipient-set]. Two DNs to the same
    # customer with different project-scoped contacts must NOT be combined,
    # otherwise we leak DN A's recipients onto DN B.
    delivery_notes.group_by { |dn| [ dn.customer_id, dn.email_recipients.sort ] }.each do |(_cid, recipients), dns|
      if recipients.empty?
        skipped_count += dns.length
        next
      end

      if dns.length == 1
        token = acceptance_token_for(dns.first)
        DeliveryNoteMailer.with(delivery_note: dns.first, acceptance_token: token).customer_email.deliver_later
      else
        acceptance_tokens = dns.each_with_object({}) do |dn, tokens|
          token = acceptance_token_for(dn)
          tokens[dn.id.to_s] = token if token
        end
        DeliveryNoteMailer.with(delivery_notes: dns, recipients: recipients, acceptance_tokens: acceptance_tokens).bulk_customer_email.deliver_later
      end
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

  # EmailableDocument hooks.
  def email_preview_document = @delivery_note

  # Previews carry a non-persisted placeholder token; sending mints a fresh real
  # one. Keeping the two apart means previewing never rotates the live token.
  def email_preview_mail = build_customer_email(skip_attachments: false, acceptance_token: preview_acceptance_token)
  def email_preview_html_mail = build_customer_email(skip_attachments: true, acceptance_token: preview_acceptance_token)
  def email_for_sending = build_customer_email(skip_attachments: false, acceptance_token: acceptance_token_for(@delivery_note))

  def build_customer_email(skip_attachments:, acceptance_token:)
    DeliveryNoteMailer.with(delivery_note: @delivery_note, skip_attachments:, acceptance_token:).customer_email
  end

  def acceptance_token_for(delivery_note)
    return nil if Settings.customer_portal.host.blank?
    delivery_note.acceptance_attachment_id.nil? ? delivery_note.issue_acceptance_upload_token! : nil
  end

  # A non-persisted placeholder token so the email preview shows the acceptance
  # link the customer will receive, without minting or rotating a real token.
  def preview_acceptance_token
    return nil if Settings.customer_portal.host.blank?
    @delivery_note&.acceptance_attachment_id.nil? ? "preview" : nil
  end

  # Document numbers are issued from a gap-free sequence; once assigned they
  # must not vanish, even if the delivery note was later unpublished.
  def require_unnumbered
    return true if @delivery_note.document_number.blank?

    flash[:error] = "Delivery notes with an assigned document number can not be deleted."
    redirect_to @delivery_note
    false
  end

  def delivery_note_params
    params.require(:delivery_note).permit(:customer_id, :project_id, :cust_reference, :cust_order, :prelude, :delivery_start_date, :delivery_end_date,
      delivery_note_lines_attributes: [ :id, :type, :title, :description, :position, :quantity, :_destroy ])
  end
end
