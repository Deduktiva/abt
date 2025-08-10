require 'json'

class InvoicesController < ApplicationController
  include EmailPreviewHelper
  # GET /invoices
  # GET /invoices.json
  def index
    # Get the selected year from params, default to current year
    @selected_year = params[:year]&.to_i || Date.current.year
    @email_filter = params[:email_filter] || 'all'

    # Filter invoices by selected year, including draft invoices (date = nil) for current year
    year_start = Date.new(@selected_year, 1, 1)
    year_end = Date.new(@selected_year, 12, 31)

    if @selected_year == Date.current.year
      # For current year, include both dated invoices and draft invoices (date = nil)
      @invoices = Invoice.where("date BETWEEN ? AND ? OR date IS NULL", year_start, year_end)
                        .reorder(Arel.sql('document_number DESC NULLS FIRST'))
    else
      # For other years, only show invoices with dates in that year
      @invoices = Invoice.where(date: year_start..year_end)
                        .reorder(Arel.sql('document_number DESC NULLS FIRST'))
    end

    case @email_filter
    when 'unsent'
      @invoices = @invoices.email_unsent.published
    when 'unpaid'
      @invoices = @invoices.unpaid
    end

    # Get available years for pagination (years that have invoices)
    # Use database-specific EXTRACT function (works in PostgreSQL, MySQL, and modern SQLite)
    year_sql = case ActiveRecord::Base.connection.adapter_name.downcase
               when 'sqlite'
                 "strftime('%Y', date)"
               else
                 "EXTRACT(YEAR FROM date)"
               end

    @available_years = Invoice.unscoped
                             .where.not(date: nil)
                             .group(Arel.sql(year_sql))
                             .order(Arel.sql("#{year_sql} DESC"))
                             .pluck(Arel.sql(year_sql))
                             .map(&:to_i)

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @invoices }
    end
  end

  # GET /invoices/1
  # GET /invoices/1.json
  def show
    @invoice = Invoice.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @invoice }
    end
  end

  # GET /invoices/new
  # GET /invoices/new.json
  def new
    @invoice = Invoice.new
    set_form_options

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @invoice }
    end
  end

  # GET /invoices/1/edit
  def edit
    @invoice = Invoice.find(params[:id])
    return unless check_unpublished

    set_form_options
  end

  # POST /invoices
  # POST /invoices.json
  def create
    @invoice = Invoice.new(invoice_params)

    respond_to do |format|
      if @invoice.save
        format.html { redirect_to @invoice, notice: 'Invoice was successfully created.' }
        format.json { render json: @invoice, status: :created, location: @invoice }
      else
        format.html { render :new, status: :unprocessable_content }
        format.json { render json: @invoice.errors, status: :unprocessable_content }
      end
    end
  end

  # PUT /invoices/1
  # PUT /invoices/1.json
  def update
    @invoice = Invoice.find(params[:id])
    return unless check_unpublished

    update_success = @invoice.update(invoice_params)

    respond_to do |format|
      if update_success
        format.html { redirect_to @invoice, notice: 'Invoice was successfully updated.' }
        format.json { head :no_content }
      else
        # If saving failed, redirect back to edit with errors
        set_form_options
        format.html { render :edit, status: :unprocessable_content }
        format.json { render json: @invoice.errors, status: :unprocessable_content }
      end
    end
  end

  # DELETE /invoices/1
  # DELETE /invoices/1.json
  def destroy
    @invoice = Invoice.find(params[:id])
    return unless check_unpublished
    @invoice.destroy

    respond_to do |format|
      format.html { redirect_to invoices_url }
      format.json { head :no_content }
    end
  end

  def book
    @invoice = Invoice.find(params[:id])

    if request.post?
      return unless check_unpublished
      # Process the booking
      want_save = (params[:save] == 'true')
      action = want_save ? 'Booking' : 'TEST-Booking'

      issuer = IssuerCompany.get_the_issuer!
      @booker = InvoiceBooker.new @invoice, issuer

      @booked = @booker.book want_save
      @booking_log = @booker.log

      if @booked
        flash[:notice] = "#{action} succeeded."
      else
        flash[:error] = "#{action} failed."
      end

      # Store simplified booking result in flash
      if @booked
        flash[:booking_success] = true
        flash[:booking_summary] = "#{action} succeeded. #{@booking_log.length} log entries."
      else
        flash[:booking_success] = false
        flash[:booking_summary] = "#{action} failed. Errors: #{@booking_log.select { |line| line.start_with?('E:') }.length}"
        # Store only error messages in flash for debugging
        errors = @booking_log.select { |line| line.start_with?('E:') }
        flash[:booking_errors] = errors.join('; ') if errors.any?
      end

      respond_to do |format|
        format.html { redirect_to book_invoice_path(@invoice) }
      end
    else
      # Show the booking results from flash data
      @booked = flash[:booking_success]
      @booking_summary = flash[:booking_summary]
      @booking_errors = flash[:booking_errors]

      # If no flash data (e.g., direct access), redirect to invoice
      if @booked.nil?
        redirect_to @invoice and return
      end

      respond_to do |format|
        format.html
      end
    end
  end

  def preview
    Rails.logger.debug "InvoiceController#preview"
    @invoice = Invoice.find(params[:id])
    return unless check_unpublished

    issuer = IssuerCompany.get_the_issuer!
    @booker = InvoiceBooker.new @invoice, issuer

    ActiveRecord::Base.transaction(requires_new: true) do
      @invoice.document_number = 'DRAFT'
      @booked = @booker.book false
      Rails.logger.debug "InvoiceBooker#book returned with #{@booked}"
      @pdf = InvoiceRenderer.new(@invoice, issuer).render if @booked
      Rails.logger.debug "InvoiceRenderer#render returned"
      raise ActiveRecord::Rollback, 'preview only'
    end

    if @booked and !@pdf.nil? and !@pdf.empty?
      send_data @pdf, type: 'application/pdf', disposition: 'inline'
    else
      log = ["Test-Booking succeeded? #{@booked}", "PDF empty: #{@pdf.nil? or @pdf.empty?}", ''] + @booker.log
      send_data log.join("\n"), type: 'text/plain', disposition: 'inline'
    end
  end

  def preview_email
    @invoice = Invoice.find(params[:id])
    mail = InvoiceMailer.with(invoice: @invoice).customer_email

    email_data = extract_email_preview_data(mail)

    respond_to do |format|
      format.html { render layout: 'application' }
      format.json { render json: email_data }
    end
  end


  def send_email
    @invoice = Invoice.find(params[:id])
    return unless check_published

    InvoiceEmailSenderJob.perform_later(@invoice.id)

    respond_to do |format|
      format.html { redirect_to @invoice, notice: 'E-Mail queued for sending.' }
      format.json { render json: @invoice, status: :ok, location: @invoice }
    end
  end

  def bulk_send_emails
    invoice_ids = params[:invoice_ids] || []
    invoice_ids = invoice_ids.reject(&:blank?)

    if invoice_ids.empty?
      redirect_to invoices_path, alert: 'No invoices selected.'
      return
    end

    invoices = Invoice.where(id: invoice_ids, published: true)
    queued_count = 0

    invoices.each do |invoice|
      if invoice.customer.email.present? || invoice.customer.invoice_email_auto_enabled
        InvoiceEmailSenderJob.perform_later(invoice.id)
        queued_count += 1
      end
    end

    respond_to do |format|
      format.html { redirect_to invoices_path, notice: "#{queued_count} emails queued for sending." }
      format.json { render json: { queued_count: queued_count }, status: :ok }
    end
  end

  def mark_paid
    @invoice = Invoice.find(params[:id])
    return unless check_published

    payment_method = params[:payment_method].presence
    payment_reference = params[:payment_reference].presence
    paid_at_param = params[:paid_at].presence
    paid_at = paid_at_param ? Time.zone.parse(paid_at_param) : Time.current

    begin
      @invoice.mark_as_paid!(
        payment_method: payment_method,
        payment_reference: payment_reference,
        paid_at: paid_at
      )
      respond_to do |format|
        format.html { redirect_to @invoice, notice: 'Invoice marked as paid.' }
        format.json { render json: @invoice, status: :ok }
      end
    rescue => e
      respond_to do |format|
        format.html { redirect_to @invoice, alert: "Failed to mark invoice as paid: #{e.message}" }
        format.json { render json: { error: e.message }, status: :unprocessable_entity }
      end
    end
  end

  def mark_unpaid
    @invoice = Invoice.find(params[:id])
    return unless check_published

    begin
      @invoice.mark_as_unpaid!
      respond_to do |format|
        format.html { redirect_to @invoice, notice: 'Invoice marked as unpaid.' }
        format.json { render json: @invoice, status: :ok }
      end
    rescue => e
      respond_to do |format|
        format.html { redirect_to @invoice, alert: "Failed to mark invoice as unpaid: #{e.message}" }
        format.json { render json: { error: e.message }, status: :unprocessable_entity }
      end
    end
  end

protected
  def check_unpublished
    if @invoice.published?
      flash[:error] = 'Published invoices can not be modified.'
      redirect_to invoice_url(@invoice)
      return false
    end
    true
  end

  def check_published
    if !@invoice.published?
      flash[:error] = 'Draft invoices can not be used for this action.'
      redirect_to invoice_url(@invoice)
      return false
    end
    true
  end

  def invoice_params
    params.require(:invoice).permit(:customer_id, :project_id, :cust_reference, :cust_order, :prelude,
      invoice_lines_attributes: [:id, :type, :title, :description, :rate, :quantity, :sales_tax_product_class_id, :position, :_destroy])
  end

  def set_form_options
    @line_type_options = InvoiceLine::TYPE_OPTIONS.to_a
  end
end
