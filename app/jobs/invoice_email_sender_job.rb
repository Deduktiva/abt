class InvoiceEmailSenderJob < ApplicationJob
  queue_as :default

  def perform(invoice_id)
    invoice = Invoice.find(invoice_id)

    # Send the email
    InvoiceMailer.with(invoice: invoice).customer_email.deliver_now

    # Mark as sent with current timestamp
    invoice.update_column(:email_sent_at, Time.current)
  end
end
