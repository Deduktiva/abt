require 'json'

class InvoicesController < ApplicationController
  include EmailPreviewHelper
  include PublishableDocument
  include DocumentWithLines

  publishable_document :invoice, label: 'invoice'
  document_with_lines line_class: InvoiceLine

  before_action :set_invoice, only: %i[show edit update destroy book preview preview_email send_email mark_paid mark_unpaid]
  before_action :require_unpublished, only: %i[edit update destroy preview]
  before_action :require_published, only: %i[send_email mark_paid mark_unpaid]

  # GET /invoices
  def index
    @selected_year = params[:year]&.to_i || Date.current.year
    @filter = params[:filter] || 'all'

    @invoices = Invoice.in_year(@selected_year, include_drafts: @selected_year == Date.current.year)
                       .reorder(Arel.sql('document_number DESC NULLS FIRST'))

    case @filter
    when 'unsent'
      @invoices = @invoices.email_unsent.published
    when 'unpaid'
      @invoices = @invoices.unpaid.published
    end

    @available_years = Invoice.available_years
  end

  # GET /invoices/1
  def show
  end

  # GET /invoices/new
  def new
    @invoice = Invoice.new
    set_form_options
  end

  # GET /invoices/1/edit
  def edit
    set_form_options
  end

  # POST /invoices
  def create
    @invoice = Invoice.new(invoice_params)

    if @invoice.save
      redirect_to @invoice, notice: 'Invoice was successfully created.'
    else
      render :new, status: :unprocessable_content
    end
  end

  # PUT /invoices/1
  def update
    if @invoice.update(invoice_params)
      redirect_to @invoice, notice: 'Invoice was successfully updated.'
    else
      set_form_options
      render :edit, status: :unprocessable_content
    end
  end

  # DELETE /invoices/1
  def destroy
    @invoice.destroy
    redirect_to invoices_url
  end

  def book
    cache_key = "booking_log_#{@invoice.id}"

    if request.post?
      return unless require_unpublished

      want_save = (params[:save] == 'true')
      action = want_save ? 'Booking' : 'TEST-Booking'

      issuer = IssuerCompany.get_the_issuer!
      booker = InvoiceBooker.new @invoice, issuer

      @booked = booker.book want_save
      Rails.cache.write(cache_key, booker.log, expires_in: 1.hour)

      flash[:booking_success] = @booked
      if @booked
        flash[:notice] = "#{action} succeeded."
      else
        flash[:error] = "#{action} failed. Errors: #{booker.log.select { |line| line.start_with?('E:') }.length}"
      end

      respond_to do |format|
        format.html { redirect_to book_invoice_path(@invoice) }
      end
    else
      # Show the booking results from flash data
      @booked = flash[:booking_success]

      # If no flash data (e.g., direct access), redirect to invoice
      if @booked.nil?
        redirect_to @invoice and return
      end

      @booking_log = Rails.cache.read(cache_key)

      respond_to do |format|
        format.html
      end
    end
  end

  def preview
    Rails.logger.debug "InvoiceController#preview"
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
    mail = InvoiceMailer.with(invoice: @invoice).customer_email

    email_data = extract_email_preview_data(mail)

    respond_to do |format|
      format.html { render layout: 'application' }
      format.json { render json: email_data }
    end
  end


  def send_email
    InvoiceMailer.with(invoice: @invoice).customer_email.deliver_later
    @invoice.update_column(:email_sent_at, Time.current)
    redirect_to @invoice, notice: 'E-Mail queued for sending.'
  end

  def mark_paid
    paid_date = params[:paid_at].presence
    @invoice.paid_at = paid_date ? Date.parse(paid_date) : Date.current
    @invoice.save!
    redirect_to @invoice, notice: "Invoice marked as paid on #{helpers.format_date(@invoice.paid_at)}."
  rescue ArgumentError
    redirect_to @invoice, alert: 'Invalid date.'
  end

  def mark_unpaid
    @invoice.update!(paid_at: nil)
    redirect_to @invoice, notice: 'Invoice marked as unpaid.'
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
    now = Time.current

    invoices.each do |invoice|
      if invoice.customer.email.present? || invoice.customer.invoice_email_auto_enabled
        InvoiceMailer.with(invoice: invoice).customer_email.deliver_later
        invoice.update_column(:email_sent_at, now)
        queued_count += 1
      end
    end

    redirect_to invoices_path, notice: "#{queued_count} emails queued for sending."
  end

protected
  def set_invoice
    @invoice = Invoice.find(params[:id])
  end

  def invoice_params
    params.require(:invoice).permit(:customer_id, :project_id, :cust_reference, :cust_order, :prelude,
      invoice_lines_attributes: [:id, :type, :title, :description, :rate, :quantity, :sales_tax_product_class_id, :position, :_destroy])
  end
end
