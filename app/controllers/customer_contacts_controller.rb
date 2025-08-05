class CustomerContactsController < ApplicationController
  before_action :set_customer, only: [:new, :create, :cancel_new]
  before_action :set_customer_contact, only: [:show, :edit, :update, :destroy, :cancel_edit]

  def new
    @customer_contact = @customer.customer_contacts.build
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "customer_contacts_#{@customer.id}",
          partial: "customers/customer_contacts_table",
          locals: { customer: @customer, show_new_form: true }
        )
      end
      format.html do
        # For regular HTML requests, redirect back to customer page
        redirect_to @customer
      end
    end
  end

  def cancel_new
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "customer_contacts_#{@customer.id}",
          partial: "customers/customer_contacts_table",
          locals: { customer: @customer, show_new_form: false }
        )
      end
      format.html do
        # For regular HTML requests, redirect back to customer page
        redirect_to @customer
      end
    end
  end

  def edit
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "customer_contact_#{@customer_contact.id}",
          partial: "customers/customer_contact_edit_form",
          locals: { contact: @customer_contact }
        )
      end
      format.html do
        # For regular HTML requests, redirect back to customer page
        redirect_to @customer_contact.customer
      end
    end
  end

  def cancel_edit
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "customer_contact_#{@customer_contact.id}",
          partial: "customers/customer_contact_row",
          locals: { contact: @customer_contact }
        )
      end
      format.html do
        # For regular HTML requests, redirect back to customer page
        redirect_to @customer_contact.customer
      end
    end
  end

  # POST /customers/:customer_id/customer_contacts
  def create
    @customer_contact = @customer.customer_contacts.build(customer_contact_params)

    respond_to do |format|
      if @customer_contact.save
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "customer_contacts_#{@customer.id}",
            partial: "customers/customer_contacts_table",
            locals: { customer: @customer, show_new_form: false }
          )
        end
        format.json { render json: { success: true, contact: @customer_contact } }
      else
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "customer_contacts_#{@customer.id}",
            partial: "customers/customer_contacts_table",
            locals: { customer: @customer, show_new_form: true, new_contact_errors: @customer_contact.errors }
          )
        end
        format.json { render json: { success: false, errors: @customer_contact.errors.full_messages } }
      end
    end
  end

  # PATCH /customer_contacts/:id
  def update
    if params[:customer_contact][:project_ids]
      # Handle project associations separately
      project_ids = params[:customer_contact][:project_ids].reject(&:blank?)
      projects = Project.where(id: project_ids)
      @customer_contact.projects = projects

      respond_to do |format|
        if @customer_contact.save
          format.turbo_stream do
            render turbo_stream: turbo_stream.replace(
              "customer_contacts_#{@customer_contact.customer.id}",
              partial: "customers/customer_contacts_table",
              locals: { customer: @customer_contact.customer, show_new_form: false }
            )
          end
          format.json { render json: { success: true } }
        else
          format.turbo_stream do
            render turbo_stream: turbo_stream.replace(
              "customer_contacts_#{@customer_contact.customer.id}",
              partial: "customers/customer_contacts_table",
              locals: { customer: @customer_contact.customer, show_new_form: false }
            )
          end
          format.json { render json: { success: false, errors: @customer_contact.errors.full_messages } }
        end
      end
    else
      # Handle regular field updates
      respond_to do |format|
        if @customer_contact.update(customer_contact_params)
          format.turbo_stream do
            render turbo_stream: turbo_stream.replace(
              "customer_contacts_#{@customer_contact.customer.id}",
              partial: "customers/customer_contacts_table",
              locals: { customer: @customer_contact.customer, show_new_form: false }
            )
          end
          format.json { render json: { success: true } }
        else
          format.turbo_stream do
            render turbo_stream: turbo_stream.replace(
              "customer_contacts_#{@customer_contact.customer.id}",
              partial: "customers/customer_contacts_table",
              locals: { customer: @customer_contact.customer, show_new_form: false }
            )
          end
          format.json { render json: { success: false, errors: @customer_contact.errors.full_messages } }
        end
      end
    end
  end

  # DELETE /customer_contacts/:id
  def destroy
    customer = @customer_contact.customer

    respond_to do |format|
      if @customer_contact.destroy
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "customer_contacts_#{customer.id}",
            partial: "customers/customer_contacts_table",
            locals: { customer: customer, show_new_form: false }
          )
        end
        format.json { render json: { success: true } }
      else
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "customer_contacts_#{customer.id}",
            partial: "customers/customer_contacts_table",
            locals: { customer: customer, show_new_form: false }
          )
        end
        format.json { render json: { success: false, errors: @customer_contact.errors.full_messages } }
      end
    end
  end

  private

  def set_customer
    @customer = Customer.find(params[:customer_id])
  end

  def set_customer_contact
    @customer_contact = CustomerContact.find(params[:id])
    @customer = @customer_contact.customer
  end

  # Permitted parameters for customer contact updates
  # When adding new document types, add the new boolean flags here:
  # params.require(:customer_contact).permit(:name, :email, :receives_invoices, :receives_quotes, :receives_statements)
  def customer_contact_params
    params.require(:customer_contact).permit(:name, :email, :receives_invoices, project_ids: [])
  end
end
