require 'json'

class InvoicesController < ApplicationController
  # GET /invoices
  # GET /invoices.json
  def index
    @invoices = Invoice.all

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

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @invoice }
    end
  end

  # GET /invoices/1/edit
  def edit
    @invoice = Invoice.find(params[:id])
    return unless check_unpublished
  end

  # POST /invoices
  # POST /invoices.json
  def create
    @invoice = Invoice.new(params[:invoice])

    respond_to do |format|
      if @invoice.save
        format.html { redirect_to @invoice, notice: 'Invoice was successfully created.' }
        format.json { render json: @invoice, status: :created, location: @invoice }
      else
        format.html { render action: 'new' }
        format.json { render json: @invoice.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /invoices/1
  # PUT /invoices/1.json
  def update
    @invoice = Invoice.find(params[:id])
    return unless check_unpublished

    success = @invoice.update_attributes(params[:invoice])
    unless params[:invoice_lines].nil? or params[:invoice_lines].empty?
      new_lines = JSON.parse params[:invoice_lines]
      puts new_lines.inspect
      @invoice.invoice_lines.delete_all
      new_lines.each do |new_line|
        line = @invoice.invoice_lines.new
        new_line.delete '$$hashKey'
        new_line.delete 'invoice_line_id'
        line.update_attributes(new_line)
      end
    end

    respond_to do |format|
      if success
        format.html { redirect_to @invoice, notice: 'Invoice was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: 'edit' }
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
    want_save = (params[:save] == 'true')
    action = want_save ? 'Booking' : 'TEST-Booking'
    @invoice = Invoice.find(params[:id])
    return unless check_unpublished

    issuer = IssuerCompany.from_config
    @booker = InvoiceBookController.new @invoice, issuer

    ActiveRecord::Base.transaction(requires_new: true) do
      @booked = @booker.book want_save
    end
    @booking_log = @booker.log

    if @booked
      flash[:notice] = "#{action} succeeded."
    else
      flash[:error] = "#{action} failed."
    end

    respond_to do |format|
      format.html
    end
  end

  def preview
    @invoice = Invoice.find(params[:id])
    return unless check_unpublished

    issuer = IssuerCompany.from_config
    @booker = InvoiceBookController.new @invoice, issuer

    ActiveRecord::Base.transaction(requires_new: true) do
      begin
        @booked = @booker.book false
        @pdf = InvoiceRenderController.new(@invoice, issuer).render if @booked
      ensure
        raise ActiveRecord::Rollback, 'preview only'
      end
    end

    if @booked and !@pdf.nil? and !@pdf.empty?
      send_data @pdf, type: 'application/pdf', disposition: 'inline'
    else
      send_data @booker.log.join("\n"), type: 'text/plain', disposition: 'inline'
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
end
