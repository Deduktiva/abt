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
    invoice.customer.update!(supplier_number: "SUP-001", country_iso2: "AT")
    invoice.save!
    assert_equal invoice.customer.name, invoice.customer_name
    assert_equal invoice.customer.address, invoice.customer_address
    assert_equal invoice.customer.id, invoice.customer_account_number.to_i
    assert_equal invoice.customer.vat_id, invoice.customer_vat_id
    assert_equal "SUP-001", invoice.customer_supplier_number
    assert_equal "AT", invoice.customer_country_iso2
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

  test "update_sums keeps cent-exact sums with no float dust under a fractional tax rate" do
    invoice = license_invoice_with_tax_config
    SalesTaxRate.find_by(
      sales_tax_customer_class: sales_tax_customer_classes(:national),
      sales_tax_product_class: sales_tax_product_classes(:standard)
    ).update!(rate: 8.25)
    invoice.invoice_lines.where(type: "item").update_all(rate: 33.33, quantity: 1)
    invoice.reload.save!
    invoice.reload

    itc = invoice.invoice_tax_classes.first
    assert_equal BigDecimal("66.66"), invoice.sum_net
    assert_equal BigDecimal("5.50"), itc.value
    assert_equal BigDecimal("72.16"), invoice.sum_total
    assert_equal invoice.sum_net + itc.value, invoice.sum_total
  end

  test "update_sums skips a published invoice" do
    invoice = invoices(:published_invoice)
    invoice.update_columns(sum_net: 999.99, sum_total: 1234.56)
    invoice.touch
    invoice.reload
    assert_equal 999.99, invoice.sum_net
    assert_equal 1234.56, invoice.sum_total
  end

  test "publish_problems is empty for a complete draft" do
    invoice = license_invoice_with_tax_config
    assert_empty invoice.publish_problems
  end

  test "publish_problems reports a missing rate using the line title" do
    invoice = license_invoice_with_tax_config
    line = invoice.invoice_lines.find_by(type: "item")
    line.update_columns(rate: nil)

    problems = invoice.reload.publish_problems
    assert(problems.any? { |p| p.include?(line.title) && p.include?("rate") })
  end

  test "publish_problems does not flag an item line whose rate is intentionally zero" do
    invoice = license_invoice_with_tax_config
    invoice.invoice_lines.where(type: "item").update_all(rate: 0)
    assert(invoice.reload.publish_problems.none? { |p| p.include?("rate") })
  end

  test "publish_problems reports a missing quantity using the line title" do
    invoice = license_invoice_with_tax_config
    line = invoice.invoice_lines.find_by(type: "item")
    line.update_columns(quantity: nil)

    problems = invoice.reload.publish_problems
    assert(problems.any? { |p| p.include?(line.title) && p.include?("quantity") })
  end

  test "publish_problems reports a missing tax config using the line title" do
    invoice = license_invoice_with_tax_config
    line = invoice.invoice_lines.find_by(type: "item")
    line.update_columns(sales_tax_product_class_id: 999_999)

    problems = invoice.reload.publish_problems
    assert(problems.any? { |p| p.include?(line.title) && p.include?("tax configuration") })
  end

  test "publish_problems reports a missing customer name" do
    invoice = license_invoice_with_tax_config
    invoice.update_columns(customer_name: nil)
    assert_includes invoice.publish_problems, "Customer name is missing."
  end

  test "publish_problems reports a missing customer address" do
    invoice = license_invoice_with_tax_config
    invoice.update_columns(customer_address: nil)
    assert_includes invoice.publish_problems, "Customer address is missing."
  end

  test "publish_problems reports an unknown customer country" do
    invoice = license_invoice_with_tax_config
    invoice.update_columns(customer_country_iso2: AddressFormatter::UNKNOWN_COUNTRY)
    assert_includes invoice.publish_problems, "Customer country is missing."
  end

  test "publish_problems reports a missing VAT ID when the customer class requires one" do
    invoice = license_invoice_with_tax_config # uses good_national (vat_id_required)
    invoice.update_columns(customer_vat_id: nil)
    assert_includes invoice.publish_problems, "Customer VAT ID is missing."
  end

  test "publish_problems does not require a VAT ID for an export customer class" do
    invoice = license_invoice_with_tax_config
    invoice.customer.update_columns(sales_tax_customer_class_id: sales_tax_customer_classes(:restoftheworld).id)
    invoice.update_columns(customer_vat_id: nil)
    invoice.reload
    assert_not_includes invoice.publish_problems, "Customer VAT ID is missing."
  end

  test "publish_problems reports a draft with no item lines" do
    invoice = license_invoice_with_tax_config
    invoice.invoice_lines.where(type: "item").destroy_all
    assert_includes invoice.reload.publish_problems, "Invoice has no item lines."
  end

  test "publish_problems is empty for a published invoice regardless of data" do
    invoice = invoices(:published_invoice)
    assert invoice.published?
    assert_empty invoice.publish_problems
  end

  # in_year / available_years (YearFilterable concern) are covered by
  # test/models/concerns/year_filterable_test.rb. The cross-team test below
  # remains — it exercises visible_to interaction, not the concern itself.
  test "available_years honors the surrounding scope (no cross-team year leak)" do
    acme = teams(:acme)
    acme_customer = Customer.create!(
      matchcode: "ACME_YEAR_LEAK",
      name: "Acme Year Leak",
      vat_id: "EU161616161",
      country_iso2: "AT",
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

  test "display_label returns the document_number when published" do
    assert_equal "INV-2024-001", invoices(:published_invoice).display_label
  end

  test "display_label returns Draft #id when unpublished" do
    draft = invoices(:draft_invoice)
    assert_equal "Draft ##{draft.id}", draft.display_label
  end

  test "display_name prepends the model name" do
    assert_equal "Invoice INV-2024-001", invoices(:published_invoice).display_name
  end

  test "publish_warnings is empty when customer has no vat_id" do
    invoice = invoices(:draft_invoice)
    invoice.customer.update_columns(vat_id: nil)
    assert_empty invoice.publish_warnings
  end

  test "publish_warnings is empty when customer class does not require a vat_id" do
    invoice = invoices(:draft_invoice)
    invoice.customer.update_columns(sales_tax_customer_class_id: sales_tax_customer_classes(:restoftheworld).id)
    assert_empty invoice.publish_warnings
  end

  test "publish_warnings reports never verified when vat_id_verified_at is nil and no verifications exist" do
    invoice = invoices(:draft_invoice)
    customer = invoice.customer
    customer.vat_verifications.destroy_all
    customer.update_columns(vat_id_verified_at: nil)
    warnings = invoice.publish_warnings
    assert(warnings.any? { |w| w.include?("never been verified") })
  end

  test "publish_warnings reports rejected by VIES when latest verification is invalid even with no vat_id_verified_at" do
    invoice = invoices(:draft_invoice)
    customer = invoice.customer
    customer.update_columns(vat_id_verified_at: nil)
    rejection_date = Date.new(2026, 5, 21)
    CustomerVatVerification.create!(
      customer: customer,
      vat_id: customer.vat_id,
      country_iso2: customer.country_iso2,
      valid_response: false,
      request_date: rejection_date,
      raw_response: "{}",
      created_at: rejection_date.beginning_of_day + 11.hours
    )
    warnings = invoice.publish_warnings
    assert(warnings.any? { |w| w.include?("rejected by VIES") && w.include?(I18n.l(rejection_date)) })
    assert_not(warnings.any? { |w| w.include?("never been verified") })
  end

  test "publish_warnings reports last verified N days ago when vat_id_verified_at is older than recheck_days" do
    invoice = invoices(:draft_invoice)
    customer = invoice.customer
    customer.vat_verifications.destroy_all
    recheck_days = IssuerCompany.get_the_issuer!.vat_id_recheck_days
    customer.update_columns(vat_id_verified_at: (recheck_days + 5).days.ago)
    warnings = invoice.publish_warnings
    assert(warnings.any? { |w| w.include?("last verified") && w.include?("threshold: #{recheck_days} days") })
  end

  test "publish_warnings is empty when vat_id_verified_at is fresh" do
    invoice = invoices(:draft_invoice)
    customer = invoice.customer
    customer.vat_verifications.destroy_all
    customer.update_columns(vat_id_verified_at: 1.day.ago)
    assert_empty invoice.publish_warnings
  end

  test "publish_warnings drops the rejected warning after the customer's vat_id is edited" do
    invoice = invoices(:draft_invoice)
    customer = invoice.customer
    customer.update_columns(vat_id_verified_at: nil)
    CustomerVatVerification.create!(
      customer: customer, vat_id: customer.vat_id, country_iso2: customer.country_iso2,
      valid_response: false, raw_response: "{}"
    )
    assert(invoice.publish_warnings.any? { |w| w.include?("rejected by VIES") })

    customer.update!(vat_id: "BE9999999999")
    warnings = invoice.publish_warnings
    assert(warnings.any? { |w| w.include?("never been verified") })
    assert_not(warnings.any? { |w| w.include?("rejected by VIES") })
  end
end
