require 'json'

class DeliveryNotesController < ApplicationController
  include EmailPreviewHelper
  include ApplicationHelper
  # GET /delivery_notes
  # GET /delivery_notes.json
  def index
    # Get the selected year from params, default to current year
    @selected_year = params[:year]&.to_i || Date.current.year
    @email_filter = params[:email_filter] || 'all'

    # Filter delivery_notes by selected year, including draft delivery_notes (date = nil) for current year
    year_start = Date.new(@selected_year, 1, 1)
    year_end = Date.new(@selected_year, 12, 31)

    if @selected_year == Date.current.year
      # For current year, include both dated delivery_notes and draft delivery_notes (date = nil)
      @delivery_notes = DeliveryNote.where("date BETWEEN ? AND ? OR date IS NULL", year_start, year_end)
                        .reorder(Arel.sql('document_number DESC NULLS FIRST'))
    else
      # For other years, only show delivery_notes with dates in that year
      @delivery_notes = DeliveryNote.where(date: year_start..year_end)
                        .reorder(Arel.sql('document_number DESC NULLS FIRST'))
    end

    case @email_filter
    when 'unsent'
      @delivery_notes = @delivery_notes.email_unsent.published
    end

    # Get available years for pagination (years that have delivery_notes)
    # Use database-specific EXTRACT function (works in PostgreSQL, MySQL, and modern SQLite)
    year_sql = case ActiveRecord::Base.connection.adapter_name.downcase
               when 'sqlite'
                 "strftime('%Y', date)"
               else
                 "EXTRACT(YEAR FROM date)"
               end

    @available_years = DeliveryNote.unscoped
                             .where.not(date: nil)
                             .group(Arel.sql(year_sql))
                             .order(Arel.sql("#{year_sql} DESC"))
                             .pluck(Arel.sql(year_sql))
                             .map(&:to_i)

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @delivery_notes }
    end
  end

  # GET /delivery_notes/1
  # GET /delivery_notes/1.json
  def show
    @delivery_note = DeliveryNote.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @delivery_note }
    end
  end

  # GET /delivery_notes/new
  # GET /delivery_notes/new.json
  def new
    @delivery_note = DeliveryNote.new
    set_form_options

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @delivery_note }
    end
  end

  # GET /delivery_notes/1/edit
  def edit
    @delivery_note = DeliveryNote.find(params[:id])
    return unless check_unpublished

    set_form_options
  end

  # POST /delivery_notes
  # POST /delivery_notes.json
  def create
    @delivery_note = DeliveryNote.new(delivery_note_params)

    respond_to do |format|
      if @delivery_note.save
        format.html { redirect_to @delivery_note, notice: 'Delivery Note was successfully created.' }
        format.json { render json: @delivery_note, status: :created, location: @delivery_note }
      else
        format.html { render :new, status: :unprocessable_content }
        format.json { render json: @delivery_note.errors, status: :unprocessable_content }
      end
    end
  end

  # PUT /delivery_notes/1
  # PUT /delivery_notes/1.json
  def update
    @delivery_note = DeliveryNote.find(params[:id])
    return unless check_unpublished

    update_success = @delivery_note.update(delivery_note_params)

    respond_to do |format|
      if update_success
        format.html { redirect_to @delivery_note, notice: 'Delivery Note was successfully updated.' }
        format.json { head :no_content }
      else
        # If saving failed, redirect back to edit with errors
        set_form_options
        format.html { render :edit, status: :unprocessable_content }
        format.json { render json: @delivery_note.errors, status: :unprocessable_content }
      end
    end
  end

  # DELETE /delivery_notes/1
  # DELETE /delivery_notes/1.json
  def destroy
    @delivery_note = DeliveryNote.find(params[:id])

    if @delivery_note.published?
      flash[:alert] = 'Published delivery notes cannot be deleted.'
      redirect_to delivery_notes_path and return
    end

    @delivery_note.destroy

    respond_to do |format|
      format.html { redirect_to delivery_notes_url }
      format.json { head :no_content }
    end
  end

  def publish
    @delivery_note = DeliveryNote.find(params[:id])
    return unless check_unpublished

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
    @delivery_note = DeliveryNote.find(params[:id])
    return unless check_unpublished

    issuer = IssuerCompany.get_the_issuer!

    @pdf = DeliveryNoteRenderer.new(@delivery_note, issuer).render

    send_data @pdf, type: 'application/pdf', disposition: 'inline'
  end

  def pdf
    @delivery_note = DeliveryNote.find(params[:id])
    return unless check_published

    issuer = IssuerCompany.get_the_issuer!

    @pdf = DeliveryNoteRenderer.new(@delivery_note, issuer).render

    filename = "#{issuer.short_name}-DeliveryNote-#{@delivery_note.document_number}.pdf"
    send_data @pdf, type: 'application/pdf', disposition: 'attachment', filename: filename
  end

  def unpublish
    @delivery_note = DeliveryNote.find(params[:id])
    return unless check_published

    @delivery_note.update!(published: false, document_number: nil, date: nil)
    flash[:notice] = "Delivery Note has been reverted to draft status."

    respond_to do |format|
      format.html { redirect_to @delivery_note }
    end
  end

  def upload_acceptance
    @delivery_note = DeliveryNote.find(params[:id])
    return unless check_published

    uploaded_file = params[:acceptance_pdf]

    if uploaded_file.blank?
      flash[:error] = "Please select a PDF file to upload."
      redirect_to @delivery_note and return
    end

    if uploaded_file.content_type != 'application/pdf'
      flash[:error] = "Only PDF files are allowed for acceptance documents."
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
    attachment.set_data uploaded_file.read, uploaded_file.content_type
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
    @delivery_note = DeliveryNote.find(params[:id])
    return unless check_published

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
    @delivery_note = DeliveryNote.find(params[:id])
    return unless check_published

    if @delivery_note.invoice_id.present?
      flash[:error] = "This delivery note has already been converted to an invoice."
      redirect_to @delivery_note and return
    end

    begin
      # Build enhanced prelude with delivery note information
      delivery_note_info = []
      delivery_note_info << "Based on Delivery Note #{@delivery_note.document_number}"
      delivery_note_info << "Delivery Note Date: #{format_date(@delivery_note.date)}" if @delivery_note.date
      if @delivery_note.acceptance_attachment
        delivery_note_info << "Acceptance Document: #{@delivery_note.acceptance_attachment.filename} (#{format_date(@delivery_note.acceptance_attachment.created_at.to_date)})"
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
          if dn_line.type == 'item'
            attrs[:quantity] = (dn_line.quantity&.to_f || 1.0).to_f
            attrs[:rate] = 0.01 # Small non-zero rate
            attrs[:sales_tax_product_class_id] = SalesTaxProductClass.first&.id
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
    @delivery_note = DeliveryNote.find(params[:id])
    mail = DeliveryNoteMailer.with(delivery_note: @delivery_note).customer_email

    email_data = extract_email_preview_data(mail)

    respond_to do |format|
      format.html { render layout: 'application' }
      format.json { render json: email_data }
    end
  end

  def send_email
    @delivery_note = DeliveryNote.find(params[:id])
    return unless check_published

    DeliveryNoteEmailSenderJob.perform_later(@delivery_note.id)

    respond_to do |format|
      format.html { redirect_to @delivery_note, notice: 'E-Mail queued for sending.' }
      format.json { render json: @delivery_note, status: :ok, location: @delivery_note }
    end
  end

  def bulk_send_emails
    delivery_note_ids = params[:delivery_note_ids] || []
    delivery_note_ids = delivery_note_ids.reject(&:blank?)

    if delivery_note_ids.empty?
      redirect_to delivery_notes_path, alert: 'No delivery notes selected.'
      return
    end

    delivery_notes = DeliveryNote.where(id: delivery_note_ids, published: true)

    # Group delivery notes by customer
    grouped_by_customer = delivery_notes.group_by(&:customer)
    queued_count = 0

    grouped_by_customer.each do |customer, customer_delivery_notes|
      if customer.email.present?
        if customer_delivery_notes.length == 1
          # Single delivery note - use existing individual email
          DeliveryNoteEmailSenderJob.perform_later(customer_delivery_notes.first.id)
        else
          # Multiple delivery notes for same customer - use bulk email
          DeliveryNoteBulkEmailSenderJob.perform_later(customer_delivery_notes.map(&:id))
        end
        queued_count += customer_delivery_notes.length
      end
    end

    respond_to do |format|
      format.html { redirect_to delivery_notes_path, notice: "#{queued_count} emails queued for sending." }
      format.json { render json: { queued_count: queued_count }, status: :ok }
    end
  end

protected
  def check_unpublished
    if @delivery_note.published?
      flash[:error] = 'Published delivery notes can not be modified.'
      redirect_to delivery_note_url(@delivery_note)
      return false
    end
    true
  end

  def check_published
    if !@delivery_note.published?
      flash[:error] = 'Draft delivery notes can not be used for this action.'
      redirect_to delivery_note_url(@delivery_note)
      return false
    end
    true
  end

  def delivery_note_params
    params.require(:delivery_note).permit(:customer_id, :project_id, :cust_reference, :cust_order, :prelude, :delivery_start_date, :delivery_end_date,
      delivery_note_lines_attributes: [:id, :type, :title, :description, :position, :quantity, :_destroy])
  end

  def set_form_options
    @line_type_options = DeliveryNoteLine::TYPE_OPTIONS.to_a
  end
end
