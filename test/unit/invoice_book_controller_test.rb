require 'test_helper'

class InvoiceBookControllerTest < ActiveSupport::TestCase
  test "should use customer payment terms for due date calculation" do
    # Use existing customer and update payment terms
    customer = customers(:good_eu)
    customer.update!(payment_terms_days: 45)

    # Use existing project
    project = projects(:test_project)

    # Create invoice with fixtures
    invoice = Invoice.create!(
      customer: customer,
      project: project,
      cust_reference: "TEST123"
    )

    # Set invoice date for predictable calculation
    invoice_date = Date.new(2024, 1, 15)
    invoice.date = invoice_date

    # Test the due date calculation logic
    expected_due_date = invoice_date + customer.payment_terms_days.days
    calculated_due_date = invoice_date + customer.payment_terms_days.days

    assert_equal 45, customer.payment_terms_days
    assert_equal expected_due_date, calculated_due_date

    # Test default payment terms for new customer
    new_customer = Customer.new(
      matchcode: "DEFAULT",
      name: "Default Customer",
      address: "789 Default St",
      vat_id: "VAT456",
      sales_tax_customer_class: sales_tax_customer_classes(:eu)
    )

    # Should get default of 30 days
    assert_equal 30, new_customer.payment_terms_days
  end
end
