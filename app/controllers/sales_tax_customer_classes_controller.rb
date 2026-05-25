class SalesTaxCustomerClassesController < ApplicationController
  before_action -> { require_permission!("sales_tax.view") }, only: [ :index, :show ]
  before_action -> { require_permission!("sales_tax.edit") }, only: [ :new, :create, :edit, :update, :destroy ]

  # GET /sales_tax_customer_classes
  def index
    @sales_tax_customer_classes = SalesTaxCustomerClass.all
  end

  # GET /sales_tax_customer_classes/1
  def show
    @sales_tax_customer_class = SalesTaxCustomerClass.find(params[:id])
  end

  # GET /sales_tax_customer_classes/new
  def new
    @sales_tax_customer_class = SalesTaxCustomerClass.new
  end

  # GET /sales_tax_customer_classes/1/edit
  def edit
    @sales_tax_customer_class = SalesTaxCustomerClass.find(params[:id])
  end

  # POST /sales_tax_customer_classes
  def create
    @sales_tax_customer_class = SalesTaxCustomerClass.new(sales_tax_customer_classes_params)

    if @sales_tax_customer_class.save
      redirect_to @sales_tax_customer_class, notice: "Sales tax customer class was successfully created."
    else
      render :new, status: :unprocessable_content
    end
  end

  # PUT /sales_tax_customer_classes/1
  def update
    @sales_tax_customer_class = SalesTaxCustomerClass.find(params[:id])

    if @sales_tax_customer_class.update(sales_tax_customer_classes_params)
      redirect_to @sales_tax_customer_class, notice: "Sales tax customer class was successfully updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  # DELETE /sales_tax_customer_classes/1
  def destroy
    @sales_tax_customer_class = SalesTaxCustomerClass.find(params[:id])
    @sales_tax_customer_class.destroy
    redirect_to sales_tax_customer_classes_url
  end

private
  def sales_tax_customer_classes_params
    params.require(:sales_tax_customer_class).permit(:name, :invoice_note, :vat_id_required)
  end
end
