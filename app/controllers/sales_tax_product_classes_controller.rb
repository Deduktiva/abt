class SalesTaxProductClassesController < ApplicationController
  # GET /sales_tax_product_classes
  def index
    @sales_tax_product_classes = SalesTaxProductClass.all
  end

  # GET /sales_tax_product_classes/1
  def show
    @sales_tax_product_class = SalesTaxProductClass.find(params[:id])
  end

  # GET /sales_tax_product_classes/new
  def new
    @sales_tax_product_class = SalesTaxProductClass.new
  end

  # GET /sales_tax_product_classes/1/edit
  def edit
    @sales_tax_product_class = SalesTaxProductClass.find(params[:id])
  end

  # POST /sales_tax_product_classes
  def create
    @sales_tax_product_class = SalesTaxProductClass.new(sales_tax_product_classes_params)

    if @sales_tax_product_class.save
      redirect_to @sales_tax_product_class, notice: 'Sales tax product class was successfully created.'
    else
      render :new, status: :unprocessable_content
    end
  end

  # PUT /sales_tax_product_classes/1
  def update
    @sales_tax_product_class = SalesTaxProductClass.find(params[:id])

    if @sales_tax_product_class.update(sales_tax_product_classes_params)
      redirect_to @sales_tax_product_class, notice: 'Sales tax product class was successfully updated.'
    else
      render :edit, status: :unprocessable_content
    end
  end

  # DELETE /sales_tax_product_classes/1
  def destroy
    @sales_tax_product_class = SalesTaxProductClass.find(params[:id])
    @sales_tax_product_class.destroy
    redirect_to sales_tax_product_classes_url
  end

private
  def sales_tax_product_classes_params
    params.require(:sales_tax_product_class).permit(:name, :indicator_code)
  end
end
