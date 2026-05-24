class SalesTaxRatesController < ApplicationController
  # GET /sales_tax_rates
  def index
    @sales_tax_rates = SalesTaxRate.all

    @class_rates = {}
    @sales_tax_rates.each do |rate|
      @class_rates[rate.sales_tax_product_class_id] ||= {}
      @class_rates[rate.sales_tax_product_class_id][rate.sales_tax_customer_class_id] = rate.id
    end

    @missing_rates = []
    SalesTaxProductClass.all.each do |pc|
      SalesTaxCustomerClass.all.each do |cc|
        if !@class_rates[pc.id] || !@class_rates[pc.id][cc.id]
          @missing_rates << { product: pc, customer: cc }
        end
      end
    end
  end

  # GET /sales_tax_rates/1
  def show
    @sales_tax_rate = SalesTaxRate.find(params[:id])
  end

  # GET /sales_tax_rates/new
  def new
    @sales_tax_rate = SalesTaxRate.new
  end

  # GET /sales_tax_rates/1/edit
  def edit
    @sales_tax_rate = SalesTaxRate.find(params[:id])
  end

  # POST /sales_tax_rates
  def create
    @sales_tax_rate = SalesTaxRate.new(sales_tax_rates_params)

    if @sales_tax_rate.save
      redirect_to sales_tax_rates_path, notice: 'Sales tax rate was successfully created.'
    else
      render :new, status: :unprocessable_content
    end
  end

  # PUT /sales_tax_rates/1
  def update
    @sales_tax_rate = SalesTaxRate.find(params[:id])

    if @sales_tax_rate.update(sales_tax_rates_params)
      redirect_to sales_tax_rates_url, notice: 'Sales tax rate was successfully updated.'
    else
      render :edit, status: :unprocessable_content
    end
  end

  # DELETE /sales_tax_rates/1
  def destroy
    @sales_tax_rate = SalesTaxRate.find(params[:id])
    @sales_tax_rate.destroy
    redirect_to sales_tax_rates_url
  end

private
  def sales_tax_rates_params
    params.require(:sales_tax_rate).permit(:sales_tax_customer_class_id, :sales_tax_product_class_id, :rate)
  end
end
