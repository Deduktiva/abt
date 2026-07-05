class CustomerContactsController < ApplicationController
  before_action -> { require_permission!("customers.view") }, only: %i[show]
  before_action -> { require_permission!("customers.edit") }, only: %i[new create edit update destroy]

  before_action :set_customer, only: %i[new create]
  before_action :set_contact,  only: %i[show edit update destroy]

  # GET /customer_contacts/:id — used by Turbo Frame "Cancel" to revert
  # an edit back to the read-only row partial.
  def show
    render partial: "customer_contacts/row", locals: { contact: @contact }
  end

  # GET /customers/:customer_id/customer_contacts/new
  # ?cancel=1 reverts the new_customer_contact frame to its add-link state.
  def new
    @contact = @customer.customer_contacts.build
    if params[:cancel]
      render partial: "customer_contacts/add_link", locals: { customer: @customer }
    end
  end

  # POST /customers/:customer_id/customer_contacts
  def create
    @contact = @customer.customer_contacts.build(contact_params)
    assign_projects(@contact, params.dig(:customer_contact, :project_ids))

    if @contact.save
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.remove("customer_contacts_empty_message"),
            turbo_stream.append("customer_contacts_tbody", partial: "customer_contacts/row", locals: { contact: @contact }),
            turbo_stream.replace("new_customer_contact", partial: "customer_contacts/add_link", locals: { customer: @customer })
          ]
        end
        format.html { redirect_to @customer }
      end
    else
      render :new, status: :unprocessable_content
    end
  end

  # GET /customer_contacts/:id/edit
  def edit
  end

  # PATCH /customer_contacts/:id
  def update
    @contact.assign_attributes(contact_params)
    assign_projects(@contact, params.dig(:customer_contact, :project_ids))

    if @contact.save
      render partial: "customer_contacts/row", locals: { contact: @contact }
    else
      render :edit, status: :unprocessable_content
    end
  end

  # DELETE /customer_contacts/:id
  def destroy
    customer = @contact.customer
    @contact.destroy
    respond_to do |format|
      format.turbo_stream do
        streams = [ turbo_stream.remove(helpers.dom_id(@contact)) ]
        unless customer.customer_contacts.exists?
          streams << turbo_stream.append("customer_contacts_tbody", partial: "customer_contacts/empty_message")
        end
        render turbo_stream: streams
      end
      format.html { redirect_to customer }
    end
  end

  private

  def set_customer
    @customer = Customer.visible_to(current_user).find(params[:customer_id])
  end

  def set_contact
    @contact  = CustomerContact.joins(:customer).merge(Customer.visible_to(current_user)).find(params[:id])
    @customer = @contact.customer
  end

  def contact_params
    params.require(:customer_contact).permit(:name, :email, :salutation_line, :receives_invoice_emails, :receives_delivery_note_emails, :receives_offer_emails)
  end

  # Server-side scope on project_ids: pick only IDs the user can see AND that
  # are eligible for this customer (their own projects or unassigned).
  def assign_projects(contact, ids)
    ids = Array(ids).reject(&:blank?).map(&:to_i)
    return contact.projects = [] if ids.empty?

    eligible = Project.visible_to(current_user)
                      .where(id: ids)
                      .where("bill_to_customer_id = ? OR bill_to_customer_id IS NULL", @customer.id)
    contact.projects = eligible.to_a
  end
end
