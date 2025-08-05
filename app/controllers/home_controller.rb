class HomeController < ApplicationController
  def index
    current_year = Date.current.year
    current_year_start = Date.new(current_year, 1, 1)

    @stats = {
      invoices_current_year: Invoice.where(date: current_year_start..Date.current).count,
      invoices_ytd_total: Invoice.where(published: true, date: current_year_start..Date.current).sum(:sum_total),
      invoices_total_count: Invoice.where(published: true).count,
      invoices_total_amount: Invoice.where(published: true).sum(:sum_total)
    }

    @data = {}
    @data[:is_setup_done] = (SalesTaxCustomerClass.count > 0 and SalesTaxProductClass.count > 0 and SalesTaxRate.count > 0)
    @data[:issuer_company] = IssuerCompany.get_the_issuer!
    respond_to do |format|
      format.html
      format.json { render :json => @stats }
    end
  end
end
