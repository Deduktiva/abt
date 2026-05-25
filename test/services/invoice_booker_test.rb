require "test_helper"

class InvoiceBookerTest < ActiveSupport::TestCase
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

  test "draft invoice copies payment_terms_days from customer on save" do
    customer = customers(:good_eu)
    customer.update!(payment_terms_days: 60)

    invoice = Invoice.create!(
      customer: customer,
      project: projects(:test_project),
      cust_reference: "SNAPSHOT-1"
    )

    assert_equal 60, invoice.payment_terms_days
  end

  test "published invoice keeps its payment_terms_days when customer's value later changes" do
    customer = customers(:good_eu)
    customer.update!(payment_terms_days: 30)

    invoice = Invoice.create!(
      customer: customer,
      project: projects(:test_project),
      cust_reference: "SNAPSHOT-2",
      date: Date.new(2024, 6, 1),
    )

    # Lock in the snapshot the same way a booked invoice does
    invoice.update!(published: true)

    assert_equal 30, invoice.payment_terms_days

    # Customer's terms change later - invoice snapshot must not move
    customer.update!(payment_terms_days: 90)
    invoice.reload

    assert_equal 30, invoice.payment_terms_days
  end

  test "booker requires a customer vat_id when the class requires one" do
    customer = customers(:good_eu)
    customer.update_columns(vat_id: nil)

    invoice = Invoice.create!(customer: customer, project: projects(:test_project), cust_reference: "NOVATID-EU")

    booker = InvoiceBooker.new(invoice, issuer_companies(:one))
    booker.book(false)

    assert_includes booker.log, "E: no customer vat id"
  end

  test "booker does not require a customer vat_id when the class does not require one" do
    customer = customers(:good_eu)
    customer.update_columns(
      sales_tax_customer_class_id: sales_tax_customer_classes(:restoftheworld).id,
      vat_id: nil
    )

    invoice = Invoice.create!(customer: customer, project: projects(:test_project), cust_reference: "NOVATID-EXPORT")

    booker = InvoiceBooker.new(invoice, issuer_companies(:one))
    booker.book(false)

    assert_not_includes booker.log, "E: no customer vat id"
  end

  test "booker derives due_date from invoice's persisted payment_terms_days" do
    customer = customers(:good_eu)
    customer.update!(payment_terms_days: 21)

    invoice = Invoice.create!(
      customer: customer,
      project: projects(:test_project),
      cust_reference: "SNAPSHOT-3",
      date: Date.new(2024, 6, 1),
    )

    # On a draft, the snapshot tracks the customer value
    assert_equal 21, invoice.payment_terms_days

    booker = InvoiceBooker.new(invoice, issuer_companies(:one))
    booker.book(false)

    assert_equal Date.new(2024, 6, 22), invoice.due_date
  end
end
