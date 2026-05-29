class CustomersController < ApplicationController
  include SearchableDropdownIndex

  before_action -> { require_permission!("customers.view") }, only: [ :index, :show ]
  before_action -> { require_permission!("customers.edit") }, only: [ :new, :create, :edit, :update, :destroy, :verify_vat_id ]

  # GET /customers
  def index
    @customers = filtered_by_active(Customer.visible_to(current_user)).order(:matchcode)
    respond_to_index_or_dropdown
  end

  # GET /customers/1
  def show
    @customer = Customer.visible_to(current_user).find(params[:id])
  end

  # GET /customers/new
  def new
    @customer = Customer.new
    teams_available = available_teams
    @customer.team_id = teams_available.first&.id if teams_available.size == 1
  end

  # GET /customers/1/edit
  def edit
    @customer = Customer.visible_to(current_user).find(params[:id])
  end

  # POST /customers
  def create
    @customer = Customer.new(customers_params)

    if @customer.save
      redirect_to @customer, notice: "Customer was successfully created."
    else
      render :new, status: :unprocessable_content
    end
  end

  # PUT /customers/1
  def update
    @customer = Customer.visible_to(current_user).find(params[:id])

    if @customer.update(customers_params)
      redirect_to @customer, notice: "Customer was successfully updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  # POST /customers/1/verify_vat_id
  def verify_vat_id
    @customer = Customer.visible_to(current_user).find(params[:id])
    if @customer.vat_id.blank?
      redirect_to @customer, alert: "Customer has no VAT ID to verify." and return
    end

    VerifyCustomerVatIdJob.perform_later(@customer, actor: current_user)
    flash[:vat_verification_pending] = true
    redirect_to @customer, notice: "VAT ID verification queued."
  end

  # DELETE /customers/1
  def destroy
    @customer = Customer.visible_to(current_user).find(params[:id])

    if @customer.destroy
      redirect_to customers_url, notice: "Customer was successfully deleted."
    else
      redirect_to customers_url, alert: @customer.errors.full_messages.join(", ")
    end
  end

private
  def customers_params
    params.require(:customer).permit(
        :matchcode, :name, :address, :country_iso2, :vat_id, :supplier_number, :notes, :sales_tax_customer_class_id, :language_id, :payment_terms_days,
        :invoice_email_auto_to, :invoice_email_auto_subject_template, :invoice_email_auto_enabled, :invoice_email_auto_contact_mode, :active,
        :team_id
    )
  end
end
