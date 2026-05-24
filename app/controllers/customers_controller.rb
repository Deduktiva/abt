class CustomersController < ApplicationController
  # GET /customers
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
    end
  end

  # GET /customers/1
  def show
    @customer = Customer.find(params[:id])
  end

  # GET /customers/new
  def new
    @customer = Customer.new
  end

  # GET /customers/1/edit
  def edit
    @customer = Customer.find(params[:id])
  end

  # POST /customers
  def create
    @customer = Customer.new(customers_params)

    if @customer.save
      redirect_to @customer, notice: 'Customer was successfully created.'
    else
      render :new, status: :unprocessable_content
    end
  end

  # PUT /customers/1
  def update
    @customer = Customer.find(params[:id])

    if @customer.update(customers_params)
      redirect_to @customer, notice: 'Customer was successfully updated.'
    else
      render :edit, status: :unprocessable_content
    end
  end

  # DELETE /customers/1
  def destroy
    @customer = Customer.find(params[:id])

    if @customer.destroy
      redirect_to customers_url, notice: 'Customer was successfully deleted.'
    else
      redirect_to customers_url, alert: @customer.errors.full_messages.join(', ')
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
