class CustomersController < ApplicationController
  # GET /customers
  # GET /customers.json
  def index
    # Show active customers by default
    params[:filter] ||= 'active'
    @customers = case params[:filter]
                 when 'all'
                   Customer.all
                 when 'inactive'
                   Customer.inactive
                 else
                   Customer.active
                 end

    @customers = @customers.order(:matchcode)

    respond_to do |format|
      format.html # index.html.erb
      format.turbo_stream { render :filter_options }
      format.json { render json: @customers }
    end
  end

  # GET /customers/1
  # GET /customers/1.json
  def show
    @customer = Customer.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @customer }
    end
  end

  # GET /customers/new
  # GET /customers/new.json
  def new
    @customer = Customer.new

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @customer }
    end
  end

  # GET /customers/1/edit
  def edit
    @customer = Customer.find(params[:id])
  end

  # POST /customers
  # POST /customers.json
  def create
    @customer = Customer.new(customers_params)

    respond_to do |format|
      if @customer.save
        format.html { redirect_to @customer, notice: 'Customer was successfully created.' }
        format.json { render json: @customer, status: :created, location: @customer }
      else
        format.html { render :new, status: :unprocessable_content }
        format.json { render json: @customer.errors, status: :unprocessable_content }
      end
    end
  end

  # PUT /customers/1
  # PUT /customers/1.json
  def update
    @customer = Customer.find(params[:id])

    respond_to do |format|
      if @customer.update(customers_params)
        format.html { redirect_to @customer, notice: 'Customer was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render :edit, status: :unprocessable_content }
        format.json { render json: @customer.errors, status: :unprocessable_content }
      end
    end
  end

  # DELETE /customers/1
  # DELETE /customers/1.json
  def destroy
    @customer = Customer.find(params[:id])

    if @customer.destroy
      respond_to do |format|
        format.html { redirect_to customers_url, notice: 'Customer was successfully deleted.' }
        format.json { head :no_content }
      end
    else
      respond_to do |format|
        format.html {
          redirect_to customers_url,
          alert: @customer.errors.full_messages.join(', ')
        }
        format.json { render json: @customer.errors, status: :unprocessable_content }
      end
    end
  end

private
  def customers_params
    params.require(:customer).permit(
        :matchcode, :name, :address, :email, :vat_id, :notes, :sales_tax_customer_class_id, :language_id, :payment_terms_days,
        :invoice_email_auto_to, :invoice_email_auto_subject_template, :invoice_email_auto_enabled, :active
    )
  end
end
