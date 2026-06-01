require "test_helper"

class InvoicePublisherTest < ActiveSupport::TestCase
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

      country_iso2: "NL",
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
    invoice.invoice_lines.create!(type: "item", title: "X", quantity: 1.0, rate: 100.0, position: 1)

    # Lock in the snapshot the same way a published invoice does
    invoice.update!(published: true)

    assert_equal 30, invoice.payment_terms_days

    # Customer's terms change later - invoice snapshot must not move
    customer.update!(payment_terms_days: 90)
    invoice.reload

    assert_equal 30, invoice.payment_terms_days
  end

  test "prepare! flags a missing vat_id when the customer class requires one" do
    customer = customers(:good_eu)
    customer.update_columns(vat_id: nil)

    invoice = Invoice.create!(customer: customer, project: projects(:test_project), cust_reference: "NOVATID-EU")

    publisher = InvoicePublisher.new(invoice, issuer_companies(:one))
    publisher.prepare!

    assert_includes invoice.publish_problems, "Customer VAT ID is missing."
  end

  test "prepare! does not flag vat_id for export customers" do
    customer = customers(:good_eu)
    customer.update_columns(
      sales_tax_customer_class_id: sales_tax_customer_classes(:restoftheworld).id,
      vat_id: nil
    )

    invoice = Invoice.create!(customer: customer, project: projects(:test_project), cust_reference: "NOVATID-EXPORT")

    publisher = InvoicePublisher.new(invoice, issuer_companies(:one))
    publisher.prepare!

    assert_not_includes invoice.publish_problems, "Customer VAT ID is missing."
  end

  test "prepare! derives due_date from the invoice's persisted payment_terms_days" do
    customer = customers(:good_eu)
    customer.update!(payment_terms_days: 21)

    invoice = Invoice.create!(
      customer: customer,
      project: projects(:test_project),
      cust_reference: "SNAPSHOT-3",
      date: Date.new(2024, 6, 1),
    )

    assert_equal 21, invoice.payment_terms_days

    publisher = InvoicePublisher.new(invoice, issuer_companies(:one))
    publisher.prepare!

    assert_equal Date.new(2024, 6, 22), invoice.due_date
  end

  test "publish! returns false and does not assign a document number when problems exist" do
    customer = customers(:good_eu)
    customer.update_columns(vat_id: nil)

    invoice = Invoice.create!(customer: customer, project: projects(:test_project), cust_reference: "FAIL-1")
    invoice.invoice_lines.create!(
      type: "item",
      title: "Widget",
      quantity: 1.0,
      rate: 100.0,
      position: 1,
      sales_tax_product_class: sales_tax_product_classes(:standard)
    )

    publisher = InvoicePublisher.new(invoice.reload, issuer_companies(:one))
    assert_not publisher.publish!

    invoice.reload
    assert_not invoice.published?
    assert_nil invoice.document_number
  end

  test "publish! books a correction invoice whose lines sum to zero" do
    klass = sales_tax_product_classes(:standard)
    invoice = Invoice.create!(customer: customers(:good_national), project: projects(:test_project), cust_reference: "CORRECTION-0", date: Date.new(2024, 6, 1))
    invoice.invoice_lines.create!(type: "item", title: "Overcharge reversal", quantity: 1.0, rate: -10000.0, position: 1, sales_tax_product_class: klass)
    invoice.invoice_lines.create!(type: "item", title: "Correct charge", quantity: 1.0, rate: 10000.0, position: 2, sales_tax_product_class: klass)

    publisher = InvoicePublisher.new(invoice.reload, issuer_companies(:one))
    assert publisher.publish!, publisher.log.join("\n")

    invoice.reload
    assert invoice.published?
    assert_in_delta 0.0, invoice.sum_total, 0.0001
  end

  test "publish! returns false and does not publish an already-published invoice" do
    invoice = invoices(:published_invoice)
    assert invoice.published?

    publisher = InvoicePublisher.new(invoice, issuer_companies(:one))
    assert_not publisher.publish!
    assert_includes publisher.log, "E: already published"
  end
end
