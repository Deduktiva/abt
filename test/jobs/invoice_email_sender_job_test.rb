require "test_helper"

class InvoiceEmailSenderJobTest < ActiveJob::TestCase
  include ActiveJob::TestHelper

  def setup
    ActionMailer::Base.deliveries.clear
  end

  test "job sends email and updates timestamp" do
    invoice = invoices(:published_invoice)
    original_sent_at = invoice.email_sent_at

    # Perform the job
    InvoiceEmailSenderJob.perform_now(invoice.id)

    # Check email was sent
    assert_equal 1, ActionMailer::Base.deliveries.size

    # Check timestamp was updated
    invoice.reload
    assert_not_nil invoice.email_sent_at
    assert_not_equal original_sent_at, invoice.email_sent_at
  end

  test "job handles customer without email" do
    invoice = invoices(:no_email_invoice)

    # Perform the job
    InvoiceEmailSenderJob.perform_now(invoice.id)

    # No email should be delivered but timestamp should be set
    assert_equal 0, ActionMailer::Base.deliveries.size

    invoice.reload
    assert_not_nil invoice.email_sent_at
  end

  test "job can be queued" do
    invoice = invoices(:published_invoice)

    assert_enqueued_jobs 1, only: InvoiceEmailSenderJob do
      InvoiceEmailSenderJob.perform_later(invoice.id)
    end
  end
end
