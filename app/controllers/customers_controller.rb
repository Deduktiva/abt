class CustomersController < ApplicationController
  before_action -> { require_permission!("customers.view") }, only: [ :index, :show ]
  before_action -> { require_permission!("customers.edit") }, only: [ :new, :create, :edit, :update, :destroy ]

  # GET /customers
  def index
    # Show active customers by default
    params[:filter] ||= "active"
    base = Customer.visible_to(current_user)
    @customers = case params[:filter]
    when "all"
      base
    when "inactive"
      base.where(active: false)
    else
      base.where(active: true)
    end

    @customers = @customers.order(:matchcode)

    respond_to do |format|
      format.html # index.html.erb
      # Only the searchable_dropdown Stimulus controller hits this branch; it sets
      # X-Requested-With explicitly. Turbo's navigation Accept also lists turbo_stream,
      # so without this guard the post-delete redirect would render dropdown options
      # into a missing target and leave the index page stale.
      format.turbo_stream { render :filter_options } if request.xhr?
      format.json {
        render json: @customers.map { |c|
          {
            id: c.id,
            matchcode: c.matchcode,
            name: c.name,
            team_id: c.team_id,
            team_name: c.team&.name
          }
        }
      }
    end
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
        :matchcode, :name, :address, :vat_id, :supplier_number, :notes, :sales_tax_customer_class_id, :language_id, :payment_terms_days,
        :invoice_email_auto_to, :invoice_email_auto_subject_template, :invoice_email_auto_enabled, :invoice_email_auto_contact_mode, :active,
        :team_id,
        :offer_boilerplate, :offer_validity_days,
        :offer_email_auto_to, :offer_email_auto_subject_template, :offer_email_auto_enabled, :offer_email_auto_contact_mode,
        :offer_milestone_split_threshold, :offer_milestone_split_first_ratio
    )
  end
end
