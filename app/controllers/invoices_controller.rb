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
    @invoice = Invoice.new(invoice_params)

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

    state = nil

    ActiveRecord::Base.transaction(requires_new: true) do
      state = {success: @invoice.update_attributes(invoice_params)}
      unless params[:invoice_lines].nil? or params[:invoice_lines].empty?
        @invoice.invoice_lines.delete_all(:delete_all)
        new_lines = JSON.parse params[:invoice_lines]
        new_lines.each do |new_line|
          new_line = ActionController::Parameters.new(new_line).permit(
              :type, :title, :description, :rate, :quantity, :sales_tax_product_class_id
          )
          unless @invoice.invoice_lines.create new_line
            state[:success] = false
          end
        end
      end
    end

    respond_to do |format|
      if state[:success]
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
      @booked = @booker.book false
      @invoice.document_number = 'XXX INVALID XXX'
      @pdf = InvoiceRenderController.new(@invoice, issuer).render if @booked
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
    params.require(:invoice).permit(:customer_id, :project_id, :cust_reference, :cust_order, :prelude)
  end
end
