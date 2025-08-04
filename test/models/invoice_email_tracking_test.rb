require "test_helper"

class InvoiceEmailTrackingTest < ActiveSupport::TestCase
  test "email_sent scope returns invoices with email_sent_at" do
    # Create an invoice with email_sent_at
    invoice = invoices(:published_invoice)
    invoice.update_column(:email_sent_at, Time.current)

    sent_invoices = Invoice.email_sent
    assert_includes sent_invoices, invoice
  end

  test "email_unsent scope returns published invoices without email_sent_at that have customer email" do
    # Get an invoice without email_sent_at but with customer email
    invoice = invoices(:published_invoice)
    invoice.update_column(:email_sent_at, nil)

    unsent_invoices = Invoice.email_unsent
    assert_includes unsent_invoices, invoice
  end

  test "email_unsent scope excludes invoices with customers without email" do
    # Get the no email invoice
    invoice = invoices(:no_email_invoice)

    unsent_invoices = Invoice.email_unsent
    assert_not_includes unsent_invoices, invoice
  end

  test "email_unsent scope includes invoices with customers with auto email enabled" do
    # Get the auto email invoice
    invoice = invoices(:auto_email_invoice)
    invoice.update_column(:email_sent_at, nil)

    unsent_invoices = Invoice.email_unsent
    assert_includes unsent_invoices, invoice
  end
end
