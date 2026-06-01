class HomeController < ApplicationController
  # Dashboard. Data is already scoped to current_user via Invoice.visible_to.
  allow_without_permission_check only: [ :index ]

  def index
    ytd_range = Date.current.beginning_of_year..Date.current

    visible = Invoice.visible_to(current_user)

    @stats = {
      invoices_current_year: visible.where(date: ytd_range).count,
      invoices_ytd_total: visible.where(published: true, date: ytd_range).sum(:sum_total),
      invoices_total_count: visible.where(published: true).count,
      invoices_total_amount: visible.where(published: true).sum(:sum_total)
    }

    @data = {}
    @data[:is_setup_done] = (SalesTaxCustomerClass.count > 0 and SalesTaxProductClass.count > 0 and SalesTaxProductClass.exists?(is_default: true) and SalesTaxRate.count > 0)
    @data[:issuer_company] = IssuerCompany.get_the_issuer!
  end
end
