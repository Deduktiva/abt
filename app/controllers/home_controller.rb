class HomeController < ApplicationController
  # Dashboard. Data is already scoped to current_user via Invoice.visible_to.
  allow_without_permission_check only: [ :index ]

  def index
    ytd_range = Date.current.beginning_of_year..Date.current
    yoy_range = Date.current.last_year.beginning_of_year..Date.current.last_year

    billed = Invoice.visible_to(current_user).where(published: true)

    @stats = {
      cashflow_ytd_total: billed.where(date: ytd_range).where("paid_at IS NOT NULL").sum(:sum_total),
      invoices_ytd_total: billed.where(date: ytd_range).sum(:sum_total),
      invoices_ytd_count: billed.where(date: ytd_range).count,
      invoices_yoy_total: billed.where(date: yoy_range).sum(:sum_total)
    }

    @data = {}
    @data[:is_setup_done] = (SalesTaxCustomerClass.count > 0 and SalesTaxProductClass.count > 0 and SalesTaxProductClass.exists?(is_default: true) and SalesTaxRate.count > 0)
    @data[:issuer_company] = IssuerCompany.get_the_issuer!

    @consistency_issues = if current_user.admin?
      DashboardConsistencyChecks.new(
        host: request.host, protocol: request.scheme, script_name: request.script_name
      ).issues
    else
      []
    end
  end
end
