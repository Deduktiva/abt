require "test_helper"

class InvoiceTest < ActiveSupport::TestCase
  # license_invoice fixture has 2 item lines (15000 + 3000) but no product class
  # assigned. Tax classes get set up via the customer's sales_tax_rates on save.
  def license_invoice_with_tax_config
    invoice = invoices(:license_invoice)
    invoice.invoice_lines.where(type: "item").update_all(
      sales_tax_product_class_id: sales_tax_product_classes(:standard).id
    )
    invoice.reload.save!
    invoice.reload
  end

  test "requires customer_id" do
    invoice = Invoice.new
    assert_not invoice.valid?
    assert_includes invoice.errors[:customer_id], "can't be blank"
  end

  test "after_initialize sets sum_net and sum_total to 0.0" do
    invoice = Invoice.new
    assert_equal 0.0, invoice.sum_net
    assert_equal 0.0, invoice.sum_total
  end

  test "published scope returns only published invoices" do
    assert_includes Invoice.published, invoices(:published_invoice)
    assert_not_includes Invoice.published, invoices(:draft_invoice)
  end

  test "unpaid scope returns invoices without paid_at" do
    paid = invoices(:published_invoice)
    paid.update_column(:paid_at, Time.current)
    assert_not_includes Invoice.unpaid, paid
    assert_includes Invoice.unpaid, invoices(:draft_invoice)
  end

  test "paid? reflects paid_at" do
    invoice = invoices(:published_invoice)
    assert_not invoice.paid?
    invoice.paid_at = Time.current
    assert invoice.paid?
  end

  test "overdue? is true for a published, unpaid invoice past its due_date" do
    invoice = invoices(:published_invoice)
    invoice.update_columns(paid_at: nil, due_date: 1.day.ago.to_date)
    assert invoice.overdue?
  end

  test "overdue? is false for a draft invoice past its due date" do
    invoice = invoices(:draft_invoice)
    invoice.update_columns(due_date: 1.day.ago.to_date)
    assert_not invoice.overdue?
  end

  test "overdue? is false for a paid invoice past its due date" do
    invoice = invoices(:published_invoice)
    invoice.update_columns(paid_at: Time.current, due_date: 1.day.ago.to_date)
    assert_not invoice.overdue?
  end

  test "overdue? is false when due_date is in the future" do
    invoice = invoices(:published_invoice)
    invoice.update_columns(paid_at: nil, due_date: 1.day.from_now.to_date)
    assert_not invoice.overdue?
  end

  test "update_customer copies customer fields to the draft invoice on save" do
    invoice = invoices(:draft_invoice)
    invoice.customer.update!(supplier_number: "SUP-001")
    invoice.save!
    assert_equal invoice.customer.name, invoice.customer_name
    assert_equal invoice.customer.address, invoice.customer_address
    assert_equal invoice.customer.id, invoice.customer_account_number.to_i
    assert_equal invoice.customer.vat_id, invoice.customer_vat_id
    assert_equal "SUP-001", invoice.customer_supplier_number
    assert_equal invoice.customer.payment_terms_days, invoice.payment_terms_days
    assert_equal invoice.customer.sales_tax_customer_class.invoice_note, invoice.tax_note
  end

  test "update_customer does not mutate a published invoice on save" do
    invoice = invoices(:published_invoice)
    invoice.update_columns(customer_name: "Frozen Name")
    invoice.customer.update!(name: "Changed Name")
    invoice.save!
    assert_equal "Frozen Name", invoice.reload.customer_name
  end

  test "update_sums computes net and total from item lines on a draft" do
    invoice = license_invoice_with_tax_config # good_national (20%), items 15000 + 3000
    assert_equal 18000, invoice.sum_net
    assert_in_delta 21600.0, invoice.sum_total, 0.0001
  end

  test "update_sums skips a published invoice" do
    invoice = invoices(:published_invoice)
    invoice.update_columns(sum_net: 999.99, sum_total: 1234.56)
    invoice.touch
    invoice.reload
    assert_equal 999.99, invoice.sum_net
    assert_equal 1234.56, invoice.sum_total
  end

  test "validate_lines_for_booking returns success for a valid line set" do
    invoice = license_invoice_with_tax_config
    result = invoice.validate_lines_for_booking
    assert result[:success], result[:errors].inspect
    assert_empty result[:errors]
  end

  test "validate_lines_for_booking reports a missing rate" do
    invoice = license_invoice_with_tax_config
    invoice.invoice_lines.find_by(type: "item").update_columns(rate: nil)

    result = invoice.reload.validate_lines_for_booking
    assert_not result[:success]
    assert(result[:errors].any? { |e| e.include?("no rate") })
  end

  test "validate_lines_for_booking reports a missing quantity" do
    invoice = license_invoice_with_tax_config
    invoice.invoice_lines.find_by(type: "item").update_columns(quantity: nil)

    result = invoice.reload.validate_lines_for_booking
    assert_not result[:success]
    assert(result[:errors].any? { |e| e.include?("no quantity") })
  end

  test "validate_lines_for_booking reports a missing tax config" do
    invoice = license_invoice_with_tax_config
    invoice.invoice_lines.find_by(type: "item").update_columns(sales_tax_product_class_id: 999_999)

    result = invoice.reload.validate_lines_for_booking
    assert_not result[:success]
    assert(result[:errors].any? { |e| e.include?("no tax config") })
  end

  test "in_year returns invoices whose date falls in the given year" do
    year = Date.current.year
    assert_includes Invoice.in_year(year), invoices(:published_invoice)

    other_year = year - 5
    assert_not_includes Invoice.in_year(other_year), invoices(:published_invoice)
  end

  test "in_year with include_drafts: true includes invoices with a null date" do
    invoices(:draft_invoice).update_columns(date: nil)
    year = Date.current.year
    assert_not_includes Invoice.in_year(year), invoices(:draft_invoice)
    assert_includes Invoice.in_year(year, include_drafts: true), invoices(:draft_invoice)
  end

  test "available_years returns distinct years with a non-null date, newest first" do
    invoices(:draft_invoice).update_columns(date: Date.new(2020, 6, 1))
    invoices(:license_invoice).update_columns(date: Date.new(2022, 4, 1))
    invoices(:no_email_invoice).update_columns(date: nil)

    years = Invoice.available_years
    assert_equal years, years.uniq.sort.reverse
    assert_includes years, 2020
    assert_includes years, 2022
    assert_not_includes years, nil
  end

  test "available_years honors the surrounding scope (no cross-team year leak)" do
    acme = teams(:acme)
    acme_customer = Customer.create!(
      matchcode: "ACME_YEAR_LEAK",
      name: "Acme Year Leak",
      vat_id: "EU161616161",
      sales_tax_customer_class: sales_tax_customer_classes(:eu),
      language: languages(:english),
      team: acme
    )
    invoice = Invoice.create!(
      customer: acme_customer,
      project: projects(:one),
      attachment: attachments(:invoice_pdf),
      date: Date.new(2019, 1, 15),
      due_date: Date.new(2019, 2, 15)
    )
    invoice.invoice_lines.create!(type: "item", title: "X", quantity: 1.0, rate: 100.0, position: 1)
    invoice.update!(published: true, document_number: "INV-ACME-YEAR", sum_net: 100, sum_total: 121)

    # blocked_carol has no team membership; she should see no invoices and
    # therefore no years.
    assert_empty Invoice.visible_to(users(:blocked_carol)).available_years

    # Unscoped, the year shows up (sanity check that the fixture took).
    assert_includes Invoice.available_years, 2019
  end

  # email_unsent + emailable? must agree (one is SQL, the other is Ruby).
  test "email_unsent includes invoices whose customer has a matching contact" do
    invoice = invoices(:published_invoice)
    invoice.update_column(:email_sent_at, nil)
    assert_includes Invoice.email_unsent, invoice
    assert invoice.emailable?
  end

  test "email_unsent excludes invoices whose only contacts are project-scoped to a different project" do
    customers(:good_eu).customer_contacts.where.not(id: customer_contacts(:good_eu_project_one_lead).id).destroy_all
    invoice = Invoice.create!(
      customer: customers(:good_eu),
      project: projects(:two),
      attachment: attachments(:invoice_pdf),
      date: Date.current, due_date: 30.days.from_now
    )
    invoice.invoice_lines.create!(type: "item", title: "X", quantity: 1.0, rate: 100.0, position: 1)
    invoice.update!(published: true, document_number: "INV-UNSENT-FILTER", sum_net: 100, sum_total: 121)

    assert_not_includes Invoice.email_unsent, invoice
    assert_not invoice.emailable?
  end

  test "email_unsent includes invoices whose customer has auto-email enabled even without contacts" do
    customers(:auto_email_customer).customer_contacts.destroy_all
    invoice = invoices(:auto_email_invoice)
    invoice.update_column(:email_sent_at, nil)

    assert_includes Invoice.email_unsent, invoice
    assert invoice.emailable?
  end

  test "email_unsent excludes invoices with no contacts and no auto-email" do
    invoice = invoices(:no_email_invoice)
    invoice.update_column(:email_sent_at, nil)
    assert_not_includes Invoice.email_unsent, invoice
    assert_not invoice.emailable?
  end

  test "emailable? is false when auto-email is enabled but auto_to is blank" do
    customer = customers(:auto_email_customer)
    customer.update_columns(invoice_email_auto_to: "")
    customer.customer_contacts.destroy_all

    invoice = invoices(:auto_email_invoice)
    invoice.update_column(:email_sent_at, nil)

    assert_not invoice.emailable?
    assert_not_includes Invoice.email_unsent, invoice
  end

  test "emailable? is false in cc_contacts mode when auto_to is blank, even if contacts exist" do
    customer = customers(:auto_email_customer)
    customer.update_columns(invoice_email_auto_to: "", invoice_email_auto_contact_mode: "cc_contacts")

    invoice = invoices(:auto_email_invoice)
    invoice.update_column(:email_sent_at, nil)

    assert_not invoice.emailable?
    assert_not_includes Invoice.email_unsent, invoice
  end

  test "emailable? is false when auto_to is whitespace-only" do
    customer = customers(:auto_email_customer)
    customer.update_columns(invoice_email_auto_to: "   ")
    customer.customer_contacts.destroy_all

    invoice = invoices(:auto_email_invoice)
    invoice.update_column(:email_sent_at, nil)

    assert_not invoice.emailable?
    assert_not_includes Invoice.email_unsent, invoice
  end
end
