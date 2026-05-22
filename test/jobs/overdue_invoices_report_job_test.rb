require "test_helper"

class OverdueInvoicesReportJobTest < ActiveJob::TestCase
  include ActiveJob::TestHelper
  include ActionMailer::TestHelper

  def setup
    ActionMailer::Base.deliveries.clear
    # Ensure no other fixture invoices are accidentally overdue.
    Invoice.update_all(paid_at: Date.current)
  end

  test "sends a single report email when overdue unpaid invoices exist" do
    overdue = invoices(:published_invoice)
    overdue.update_columns(published: true, due_date: 5.days.ago.to_date, paid_at: nil)

    assert_emails 1 do
      OverdueInvoicesReportJob.perform_now
    end

    delivered = ActionMailer::Base.deliveries.last
    assert_match overdue.document_number, delivered.html_part.body.to_s
  end

  test "sends nothing when there are no overdue invoices" do
    assert_emails 0 do
      OverdueInvoicesReportJob.perform_now
    end
  end

  test "ignores draft invoices" do
    draft = invoices(:draft_invoice)
    draft.update_columns(published: false, due_date: 5.days.ago.to_date, paid_at: nil)

    assert_emails 0 do
      OverdueInvoicesReportJob.perform_now
    end
  end

  test "ignores paid invoices" do
    paid = invoices(:published_invoice)
    paid.update_columns(published: true, due_date: 5.days.ago.to_date, paid_at: 1.day.ago.to_date)

    assert_emails 0 do
      OverdueInvoicesReportJob.perform_now
    end
  end

  test "ignores invoices whose due_date is today or later" do
    not_yet_due = invoices(:published_invoice)
    not_yet_due.update_columns(published: true, due_date: Date.current, paid_at: nil)

    assert_emails 0 do
      OverdueInvoicesReportJob.perform_now
    end
  end

  test "can be queued" do
    assert_enqueued_jobs 1, only: OverdueInvoicesReportJob do
      OverdueInvoicesReportJob.perform_later
    end
  end
end
