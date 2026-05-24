class HomeController < ApplicationController
  def index
    ytd_range = Date.current.beginning_of_year..Date.current

    @stats = {
      invoices_current_year: Invoice.where(date: ytd_range).count,
      invoices_ytd_total: Invoice.where(published: true, date: ytd_range).sum(:sum_total),
      invoices_total_count: Invoice.where(published: true).count,
      invoices_total_amount: Invoice.where(published: true).sum(:sum_total)
    }

    @data = {}
    @data[:is_setup_done] = (SalesTaxCustomerClass.count > 0 and SalesTaxProductClass.count > 0 and SalesTaxRate.count > 0)
    @data[:issuer_company] = IssuerCompany.get_the_issuer!
  end
end
