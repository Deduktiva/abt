class SalesTaxProductClassesController < ApplicationController
  # GET /sales_tax_product_classes
  # GET /sales_tax_product_classes.json
  def index
    @sales_tax_product_classes = SalesTaxProductClass.all

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @sales_tax_product_classes }
    end
  end

  # GET /sales_tax_product_classes/1
  # GET /sales_tax_product_classes/1.json
  def show
    @sales_tax_product_class = SalesTaxProductClass.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @sales_tax_product_class }
    end
  end

  # GET /sales_tax_product_classes/new
  # GET /sales_tax_product_classes/new.json
  def new
    @sales_tax_product_class = SalesTaxProductClass.new

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @sales_tax_product_class }
    end
  end

  # GET /sales_tax_product_classes/1/edit
  def edit
    @sales_tax_product_class = SalesTaxProductClass.find(params[:id])
  end

  # POST /sales_tax_product_classes
  # POST /sales_tax_product_classes.json
  def create
    @sales_tax_product_class = SalesTaxProductClass.new(sales_tax_product_classes_params)

    respond_to do |format|
      if @sales_tax_product_class.save
        format.html { redirect_to @sales_tax_product_class, notice: 'Sales tax product class was successfully created.' }
        format.json { render json: @sales_tax_product_class, status: :created, location: @sales_tax_product_class }
      else
        format.html { render action: "new" }
        format.json { render json: @sales_tax_product_class.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /sales_tax_product_classes/1
  # PUT /sales_tax_product_classes/1.json
  def update
    @sales_tax_product_class = SalesTaxProductClass.find(params[:id])

    respond_to do |format|
      if @sales_tax_product_class.update(sales_tax_product_classes_params)
        format.html { redirect_to @sales_tax_product_class, notice: 'Sales tax product class was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render action: "edit" }
        format.json { render json: @sales_tax_product_class.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /sales_tax_product_classes/1
  # DELETE /sales_tax_product_classes/1.json
  def destroy
    @sales_tax_product_class = SalesTaxProductClass.find(params[:id])
    @sales_tax_product_class.destroy

    respond_to do |format|
      format.html { redirect_to sales_tax_product_classes_url }
      format.json { head :no_content }
    end
  end

private
  def sales_tax_product_classes_params
    params.require(:sales_tax_product_class).permit(:name, :indicator_code)
  end
end
