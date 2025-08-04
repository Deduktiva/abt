class SalesTaxRatesController < ApplicationController
  # GET /sales_tax_rates
  # GET /sales_tax_rates.json
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
          @missing_rates << {:product => pc, :customer => cc}
        end
      end
    end

    respond_to do |format|
      format.html # index.html.erb
      format.json { render json: @sales_tax_rates }
    end
  end

  # GET /sales_tax_rates/1
  # GET /sales_tax_rates/1.json
  def show
    @sales_tax_rate = SalesTaxRate.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.json { render json: @sales_tax_rate }
    end
  end

  # GET /sales_tax_rates/new
  # GET /sales_tax_rates/new.json
  def new
    @sales_tax_rate = SalesTaxRate.new

    respond_to do |format|
      format.html # new.html.erb
      format.json { render json: @sales_tax_rate }
    end
  end

  # GET /sales_tax_rates/1/edit
  def edit
    @sales_tax_rate = SalesTaxRate.find(params[:id])
  end

  # POST /sales_tax_rates
  # POST /sales_tax_rates.json
  def create
    @sales_tax_rate = SalesTaxRate.new(sales_tax_rates_params)

    respond_to do |format|
      if @sales_tax_rate.save
        format.html { redirect_to sales_tax_rates_path, notice: 'Sales tax rate was successfully created.' }
        format.json { render json: @sales_tax_rate, status: :created, location: @sales_tax_rate }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @sales_tax_rate.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /sales_tax_rates/1
  # PUT /sales_tax_rates/1.json
  def update
    @sales_tax_rate = SalesTaxRate.find(params[:id])

    respond_to do |format|
      if @sales_tax_rate.update(sales_tax_rates_params)
        format.html { redirect_to sales_tax_rates_url, notice: 'Sales tax rate was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @sales_tax_rate.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /sales_tax_rates/1
  # DELETE /sales_tax_rates/1.json
  def destroy
    @sales_tax_rate = SalesTaxRate.find(params[:id])
    @sales_tax_rate.destroy

    respond_to do |format|
      format.html { redirect_to sales_tax_rates_url }
      format.json { head :no_content }
    end
  end

private
  def sales_tax_rates_params
    params.require(:sales_tax_rate).permit(:sales_tax_customer_class_id, :sales_tax_product_class_id, :rate)
  end
end
