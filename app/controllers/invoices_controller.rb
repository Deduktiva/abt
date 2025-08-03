require 'json'

class InvoicesController < ApplicationController
  # GET /invoices
  # GET /invoices.json
  def index
    # Get the selected year from params, default to current year
    @selected_year = params[:year]&.to_i || Date.current.year

    # Filter invoices by selected year
    year_start = Date.new(@selected_year, 1, 1)
    year_end = Date.new(@selected_year, 12, 31)

    @invoices = Invoice.where(date: year_start..year_end)
                      .reorder(Arel.sql('document_number DESC NULLS FIRST'))

    # Get available years for pagination (years that have invoices)
    @available_years = Invoice.where.not(date: nil)
                             .group(Arel.sql("strftime('%Y', date)"))
                             .order(Arel.sql("strftime('%Y', date) DESC"))
                             .pluck(Arel.sql("strftime('%Y', date)"))
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
        format.html { render template: 'new' }
        format.json { render json: @invoice.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /invoices/1
  # PUT /invoices/1.json
  def update
    @invoice = Invoice.find(params[:id])
    return unless check_unpublished

    state = {success: @invoice.update(invoice_params)}

    respond_to do |format|
      if state[:success]
        format.html { redirect_to @invoice, notice: 'Invoice was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render template: 'edit' }
        format.json { render json: @invoice.errors, status: :unprocessable_entity }
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
      @booker = InvoiceBookController.new @invoice, issuer

      ActiveRecord::Base.transaction(requires_new: true) do
        @booked = @booker.book want_save
        unless want_save
          raise ActiveRecord::Rollback, 'preview only'
        end
      end
      @booking_log = @booker.log

      if @booked
        flash[:notice] = "#{action} succeeded."
      else
        flash[:error] = "#{action} failed."
      end

      # Store booking data in session for the redirected page
      session[:booking_log] = @booking_log
      session[:booked] = @booked

      respond_to do |format|
        format.html { redirect_to book_invoice_path(@invoice) }
      end
    else
      # Show the booking results from session data
      @booking_log = session.delete(:booking_log)
      @booked = session.delete(:booked)

      # If no session data (e.g., browser back button), redirect to invoice
      if @booking_log.nil? && @booked.nil?
        redirect_to @invoice and return
      end

      @booking_log ||= []
      @booked ||= false

      respond_to do |format|
        format.html
      end
    end
  end

  def test_booking
    @invoice = Invoice.find(params[:id])
    return unless check_unpublished

    # Update invoice if there are form params (called from edit page)
    update_success = true
    if params[:invoice].present?
      update_success = @invoice.update(invoice_params)
    end

    if update_success
      # Run the test booking calculation and persist the totals
      issuer = IssuerCompany.get_the_issuer!
      @booker = InvoiceBookController.new @invoice, issuer

      # Use the tax calculator to compute and persist totals without publishing
      calculator = InvoiceTaxCalculator.new(@invoice)
      @booked = calculator.calculate!
      @booking_log = calculator.log

      # Store booking data in session for the redirected page
      session[:booking_log] = @booking_log
      session[:booked] = @booked

      if @booked
        flash[:notice] = "Test booking succeeded."
      else
        flash[:error] = "Test booking failed."
      end

      respond_to do |format|
        format.html { redirect_to @invoice }
      end
    else
      # If saving failed, redirect back to edit with errors
      set_form_options
      respond_to do |format|
        format.html { render :edit }
      end
    end
  end

  def preview
    Rails.logger.debug "InvoiceController#preview"
    @invoice = Invoice.find(params[:id])
    return unless check_unpublished

    issuer = IssuerCompany.get_the_issuer!
    @booker = InvoiceBookController.new @invoice, issuer

    ActiveRecord::Base.transaction(requires_new: true) do
      @invoice.document_number = 'DRAFT'
      @booked = @booker.book false
      Rails.logger.debug "InvoiceBookController#book returned with #{@booked}"
      @pdf = InvoiceRenderController.new(@invoice, issuer).render if @booked
      Rails.logger.debug "InvoiceRenderController#render returned"
      raise ActiveRecord::Rollback, 'preview only'
    end

    if @booked and !@pdf.nil? and !@pdf.empty?
      send_data @pdf, type: 'application/pdf', disposition: 'inline'
    else
      log = ["Test-Booking succeeded? #{@booked}", "PDF empty: #{@pdf.nil? or @pdf.empty?}", ''] + @booker.log
      send_data log.join("\n"), type: 'text/plain', disposition: 'inline'
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

  def invoice_params
    params.require(:invoice).permit(:customer_id, :project_id, :cust_reference, :cust_order, :prelude,
      invoice_lines_attributes: [:id, :type, :title, :description, :rate, :quantity, :sales_tax_product_class_id, :position, :_destroy])
  end

  def set_form_options
    @line_type_options = InvoiceLine::TYPE_OPTIONS.to_a
  end
end
