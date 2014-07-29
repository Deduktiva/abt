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
    if @invoice.published?
      format.json { render status: :forbidden }
      format.html { render status: :forbidden }
      return
    end

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
    if @invoice.published?
      format.json { render status: :forbidden }
      format.html { render status: :forbidden }
      return
    end
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
    if @invoice.published?
      format.json { render status: :forbidden }
      format.html { render status: :forbidden }
      return
    end

    issuer = IssuerCompany.from_config
    booker = InvoiceBookController.new @invoice, issuer
    @booking_log = booker.log
    @booking_failed = booker.failed
    if booker.book want_save
      flash[:notice] = "#{action} succeeded."
    else
      flash[:error] = "#{action} failed."
    end

    respond_to do |format|
      format.html
    end
  end

  def publish


    # @attachment = Attachment.new
    # @attachment.uploaded_file = params[:attachment][:attachment]
    # @attachment.title = params[:attachment][:title]
    #
    # if @attachment.save
    #   flash[:notice] = "Attachment created."
    #   redirect_to :action => "index"  # FIXME: do something useful
    # else
    #   flash[:error] = "Saving attachment failed."
    #   render :action => "new"
    # end

  end

  def preview
    invoice = Invoice.find(params[:id])
    unless invoice.published?
      invoice.customer_name = invoice.customer.name
      invoice.customer_address = invoice.customer.address
      invoice.customer_account_number = invoice.customer.id
      invoice.customer_supplier_number = invoice.customer.supplier_number
      invoice.customer_vat_id = invoice.customer.vat_id
    end

    issuer = IssuerCompany.from_config

    renderer = InvoiceRenderController.new invoice, issuer
    pdf = renderer.render
    send_data pdf, type: 'application/pdf', disposition: 'inline'
  end
end
