class OverdueInvoicesReportJob < ApplicationJob
  queue_as :default

  def perform
    overdue = Invoice.published.unpaid
                     .where("due_date < ?", Date.current)
                     .includes(:customer)
                     .order(:due_date)

    return if overdue.empty?

    OverdueInvoicesMailer.with(invoices: overdue).overdue_report.deliver_now
  end
end
