class SalesTaxCustomerClassesController < ApplicationController
  # GET /sales_tax_customer_classes
  # GET /sales_tax_customer_classes.json
  def index
    @sales_tax_customer_classes = SalesTaxCustomerClass.all

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @sales_tax_customer_classes }
    end
  end

  # GET /sales_tax_customer_classes/1
  # GET /sales_tax_customer_classes/1.json
  def show
    @sales_tax_customer_class = SalesTaxCustomerClass.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @sales_tax_customer_class }
    end
  end

  # GET /sales_tax_customer_classes/new
  # GET /sales_tax_customer_classes/new.json
  def new
    @sales_tax_customer_class = SalesTaxCustomerClass.new

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @sales_tax_customer_class }
    end
  end

  # GET /sales_tax_customer_classes/1/edit
  def edit
    @sales_tax_customer_class = SalesTaxCustomerClass.find(params[:id])
  end

  # POST /sales_tax_customer_classes
  # POST /sales_tax_customer_classes.json
  def create
    @sales_tax_customer_class = SalesTaxCustomerClass.new(sales_tax_customer_classes_params)

    respond_to do |format|
      if @sales_tax_customer_class.save
        format.html { redirect_to @sales_tax_customer_class, notice: 'Sales tax customer class was successfully created.' }
        format.json { render json: @sales_tax_customer_class, status: :created, location: @sales_tax_customer_class }
      else
        format.html { render :new, status: :unprocessable_content }
        format.json { render json: @sales_tax_customer_class.errors, status: :unprocessable_content }
      end
    end
  end

  # PUT /sales_tax_customer_classes/1
  # PUT /sales_tax_customer_classes/1.json
  def update
    @sales_tax_customer_class = SalesTaxCustomerClass.find(params[:id])

    respond_to do |format|
      if @sales_tax_customer_class.update(sales_tax_customer_classes_params)
        format.html { redirect_to @sales_tax_customer_class, notice: 'Sales tax customer class was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render :edit, status: :unprocessable_content }
        format.json { render json: @sales_tax_customer_class.errors, status: :unprocessable_content }
      end
    end
  end

  # DELETE /sales_tax_customer_classes/1
  # DELETE /sales_tax_customer_classes/1.json
  def destroy
    @sales_tax_customer_class = SalesTaxCustomerClass.find(params[:id])
    @sales_tax_customer_class.destroy

    respond_to do |format|
      format.html { redirect_to sales_tax_customer_classes_url }
      format.json { head :no_content }
    end
  end

private
  def sales_tax_customer_classes_params
    params.require(:sales_tax_customer_class).permit(:name, :invoice_note)
  end
end
