class HomeController < ApplicationController
  def index
    @stats = {
      :customers => Customer.count
    }
    @is_setup_done = (SalesTaxCustomerClass.count > 0 and SalesTaxProductClass.count > 0 and SalesTaxRate.count > 0)
    respond_to do |format|
      format.html
      format.json { render :json => @stats }
    end
  end
end
