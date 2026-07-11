require "test_helper"

class InvoicesControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get invoices_url
    assert_response :success
  end

  test "should get index with year filter" do
    create_draft_invoice(customer: customers(:good_eu), internal_reference: "2023-TEST", date: Date.new(2023, 6, 15))
    create_draft_invoice(internal_reference: "2024-TEST", date: Date.new(2024, 6, 15))

    # Test current year (default)
    get invoices_url
    assert_response :success
    assert_select ".year-pagination"
    assert_select "td", text: customers(:good_eu).matchcode

    # Test specific year filter
    get invoices_url(year: 2023)
    assert_response :success
    # Verify the page contains the 2023 invoice reference but not 2024
    assert_select "td", text: "2023-TEST"
    assert_select "td", text: "2024-TEST", count: 0

    # Test "all" year filter — invoices from every year are shown
    get invoices_url(year: "all")
    assert_response :success
    assert_select "td", text: "2023-TEST"
    assert_select "td", text: "2024-TEST"
    assert_select ".year-pagination a.active", text: "All"
  end

  test "should filter invoices by customer" do
    create_draft_invoice(customer: customers(:good_eu), internal_reference: "EU-CUSTOMER-INV", date: Date.current)
    create_draft_invoice(customer: customers(:good_national), internal_reference: "NATIONAL-CUSTOMER-INV", date: Date.current)

    get invoices_url(customer_id: customers(:good_eu).id)
    assert_response :success
    assert_select "td", text: customers(:good_eu).matchcode, count: 0
    assert_select "td", text: "EU-CUSTOMER-INV"
    assert_select "td", text: "NATIONAL-CUSTOMER-INV", count: 0
  end

  test "index renders customer dropdown" do
    get invoices_url
    assert_response :success
    assert_select "select[name='customer_id']" do
      assert_select "option[value='']"
      customer = customers(:good_eu)
      assert_select "option[value=?][data-full=?]", customer.id.to_s, "#{customer.matchcode} — #{customer.name}", text: customer.matchcode
    end
  end

  test "customer dropdown excludes inactive customers" do
    inactive = customers(:good_national)
    inactive.update!(active: false)
    create_draft_invoice(customer: inactive, internal_reference: "INACTIVE-CUST-INV", date: Date.current)

    get invoices_url
    assert_response :success
    assert_select "select[name='customer_id']" do
      assert_select "option[value=?]", inactive.id.to_s, count: 0
    end
  end

  test "customer dropdown still includes inactive customer if currently selected" do
    inactive = customers(:good_national)
    inactive.update!(active: false)
    create_draft_invoice(customer: inactive, internal_reference: "INACTIVE-CUST-INV", date: Date.current)

    get invoices_url(customer_id: inactive.id)
    assert_response :success
    assert_select "select[name='customer_id']" do
      assert_select "option[value=?][selected]", inactive.id.to_s
    end
    assert_select "td", text: "INACTIVE-CUST-INV"
  end

  test "should include draft invoices with nil date in current year" do
    current_year = Date.current.year

    create_draft_invoice(internal_reference: "DRAFT-NO-DATE")  # date is nil
    create_draft_invoice(internal_reference: "OLD-BOOKED", date: Date.new(current_year - 1, 6, 15))

    # Test current year (should include draft invoice)
    get invoices_url(year: current_year)
    assert_response :success
    assert_select "td", text: "DRAFT-NO-DATE"  # Draft should appear
    assert_select "td", text: "OLD-BOOKED", count: 0  # Old invoice should not appear

    # Test previous year (should include old invoice, not draft)
    get invoices_url(year: current_year - 1)
    assert_response :success
    assert_select "td", text: "OLD-BOOKED"  # Old invoice should appear
    assert_select "td", text: "DRAFT-NO-DATE", count: 0  # Draft should not appear in old year
  end

  test "drafts sort newest-first when document_number is null" do
    first  = create_draft_invoice(internal_reference: "DRAFT-FIRST")
    second = create_draft_invoice(internal_reference: "DRAFT-SECOND")
    third  = create_draft_invoice(internal_reference: "DRAFT-THIRD")

    get invoices_url
    assert_response :success

    body = @response.body
    positions = [ third, second, first ].map { |inv| body.index(inv.internal_reference) }
    assert positions.all?, "all drafts should be rendered: #{positions.inspect}"
    assert_equal positions, positions.sort, "drafts should render in id DESC order (newest first): #{positions.inspect}"
  end

  test "should get new" do
    get new_invoice_url
    assert_response :success
  end

  test "new prefills customer when customer_id param is given" do
    customer = customers(:good_eu)
    get new_invoice_url(customer_id: customer.id)
    assert_response :success
    assert_select "input#invoice_customer_id[value=?]", customer.id.to_s
  end

  test "should create invoice" do
    assert_difference("Invoice.count") do
      post invoices_url, params: {
        invoice: {
          customer_id: customers(:good_eu).id,
          project_id: projects(:test_project).id,
          cust_reference: "REF123",
          cust_order: "ORDER456",
          prelude: "Test invoice"
        }
      }
    end
    assert_redirected_to edit_invoice_url(Invoice.last)
  end

  test "editing a freshly created invoice shows a focused starter line" do
    post invoices_url, params: { invoice: { customer_id: customers(:good_eu).id, project_id: projects(:test_project).id } }
    follow_redirect!
    assert_select "[data-invoice-lines-target='container']" do
      assert_select "[data-line-index]", 1
      assert_select "input[name*='[title]'][autofocus]", 1
    end
  end

  test "should show invoice" do
    invoice = create_draft_invoice(cust_reference: "TEST")
    get invoice_url(invoice)
    assert_response :success
  end

  test "preview_email reports emailable false without building a mail when there is no recipient" do
    get preview_email_invoice_url(invoices(:no_email_invoice), format: :json)
    assert_response :success
    assert_equal({ "emailable" => false }, JSON.parse(response.body))
  end

  test "preview_email_html renders the email HTML body" do
    invoice = invoices(:published_invoice)
    get preview_email_html_invoice_url(invoice)
    assert_response :success
    assert_includes response.body, "Dear #{invoice.customer.name}"
  end

  test "preview_email_html renders a plaintext fallback when there is no HTML body" do
    get preview_email_html_invoice_url(invoices(:no_email_invoice))
    assert_response :success
    assert_equal "text/plain", response.media_type
    assert_match "No HTML body", response.body
  end

  test "should show published invoice with tax classes" do
    invoice = Invoice.create!(
      customer: customers(:good_eu),
      project: projects(:test_project),
      cust_reference: "TEST",
      document_number: "INV-TEST-UNIQUE",
      date: Date.current,
      sum_net: 200.0,
      sum_total: 238.0
    )

    # Add invoice lines (must exist before transitioning to published)
    invoice.invoice_lines.create!(
      type: "item",
      title: "Test Product",
      description: "A test product",
      rate: 100.0,
      quantity: 2.0,
      sales_tax_product_class: sales_tax_product_classes(:standard),
      position: 1
    )
    invoice.update!(published: true)

    # update_sums auto-created the tax class for the standard product class
    # when the invoice was first saved. Populate it with the totals this
    # test wants to render.
    tax_class = invoice.invoice_tax_classes.find_by!(sales_tax_product_class: sales_tax_product_classes(:standard))
    tax_class.update!(rate: 19.0, value: 38.0, total: 238.0, net: 200.0)

    get invoice_url(invoice)
    assert_response :success
    assert_select "table.document-lines-table"
    assert_select ".badge.bg-success", text: "Booked"
  end

  test "draft invoice without lines renders inline Edit Lines button" do
    invoice = create_draft_invoice(internal_reference: "EMPTY")

    get invoice_url(invoice)
    assert_response :success
    assert_select "table.document-lines-table tbody a", text: "Edit Lines", href: edit_invoice_path(invoice)
  end

  test "draft invoice show renders Publish Status row with Ready badge for a valid draft" do
    invoice = create_invoice_with_item_line(cust_reference: "TEST_DRAFT", quantity: 1.0)

    get invoice_url(invoice)
    assert_response :success
    assert_select ".badge.bg-warning", text: "Draft"
    assert_select ".badge.bg-success", text: "Ready"
    assert_select "form.button_to button", text: /Publish/
  end

  test "draft invoice show renders problems alert and disabled Publish button when invoice has missing data" do
    invoice = create_invoice_with_item_line(
      cust_reference: "MISSING_RATE",
      quantity: 1.0,
      line_overrides: { title: "Broken Line", rate: 1.0 }
    )
    invoice.invoice_lines.first.update_columns(rate: nil)

    get invoice_url(invoice)
    assert_response :success
    assert_select ".alert-warning li", text: /Broken Line.*rate/
    assert_select "button[disabled]", text: /Publish/
  end

  test "should get edit" do
    invoice = create_draft_invoice(cust_reference: "TEST")
    get edit_invoice_url(invoice)
    assert_response :success
    assert_select "[data-invoice-lines-target='container'] [data-line-index]", 0
  end

  test "should get edit with existing lines" do
    invoice = create_draft_invoice(cust_reference: "TEST")

    # Add some invoice lines to test the HAML template rendering
    invoice.invoice_lines.create!(
      type: "item",
      title: "Test Product",
      description: "A test product",
      rate: 100.0,
      quantity: 2.0,
      sales_tax_product_class: sales_tax_product_classes(:standard),
      position: 1
    )

    invoice.invoice_lines.create!(
      type: "text",
      title: "Note",
      description: "Additional information",
      position: 2
    )

    get edit_invoice_url(invoice)
    assert_response :success
  end

  test "should update invoice with nested attributes" do
    invoice = create_draft_invoice(customer: customers(:good_national), internal_reference: "TEST")  # good_national has 20% tax

    patch invoice_url(invoice), params: {
      invoice: {
        internal_reference: "UPDATED_REF",
        invoice_lines_attributes: {
          "0" => {
            type: "item",
            title: "Test Product",
            description: "A test product",
            rate: "100.00",
            quantity: "2",
            position: "1",
            sales_tax_product_class_id: sales_tax_product_classes(:standard).id
          },
          "1" => {
            type: "text",
            title: "Note",
            description: "Additional information",
            position: "2"
          }
        }
      }
    }

    assert_redirected_to invoice_url(invoice)
    invoice.reload
    assert_equal "UPDATED_REF", invoice.internal_reference
    assert_equal 2, invoice.invoice_lines.count
    assert_equal "Test Product", invoice.invoice_lines.first.title

    # Verify totals are calculated correctly
    invoice.reload
    assert invoice.sum_net == 200.0, "sum_net should be calculated (#{invoice.sum_net})"
    assert invoice.sum_total == 240.0, "sum_total should be calculated (#{invoice.sum_total})"
    assert invoice.invoice_tax_classes.any?, "tax classes should be created"
  end

  test "should handle updating invoice with validation errors" do
    invoice = create_draft_invoice(cust_reference: "TEST")

    patch invoice_url(invoice), params: {
      invoice: {
        customer_id: nil, # This should cause validation error
        cust_reference: "INVALID"
      }
    }

    assert_response :unprocessable_content
  end

  test "publish action publishes a valid draft and redirects to show with published=1" do
    invoice = create_invoice_with_item_line(cust_reference: "PUBLISH_OK")

    post publish_invoice_url(invoice)

    assert_redirected_to invoice_path(invoice, published: 1)
    invoice.reload
    assert invoice.published?
    assert invoice.document_number.present?
    assert invoice.attachment.present?
  end

  test "publish action redirects with flash[:error] when invoice has publish problems" do
    invoice = create_invoice_with_item_line(
      cust_reference: "PUBLISH_FAIL",
      line_overrides: { title: "Missing Rate Item", rate: 1.0 }
    )
    invoice.invoice_lines.first.update_columns(rate: nil)

    post publish_invoice_url(invoice)

    assert_redirected_to invoice_url(invoice)
    assert_match(/Publishing failed/, flash[:error])
    assert_not invoice.reload.published?
    assert_nil invoice.document_number
  end

  test "should reuse existing tax classes during update" do
    invoice = create_draft_invoice(cust_reference: "TEST")

    # Add an invoice line
    invoice.invoice_lines.create!(
      type: "item",
      title: "Test Product",
      description: "A test product",
      rate: 100.0,
      quantity: 2.0,
      sales_tax_product_class: sales_tax_product_classes(:standard),
      position: 1
    )

    # Run an update to create tax classes
    patch invoice_url(invoice), params: { invoice: { cust_reference: "NEW_REF" } }
    invoice.reload

    # Remember the tax class ID
    original_tax_class = invoice.invoice_tax_classes.first
    original_id = original_tax_class.id

    # Modify the invoice to trigger recalculation
    invoice.invoice_lines.first.update!(quantity: 3.0)

    # Run update again - should reuse existing tax class
    patch invoice_url(invoice), params: { invoice: { cust_reference: "NEW_REF2" } }
    invoice.reload

    # Verify the tax class was updated, not recreated
    updated_tax_class = invoice.invoice_tax_classes.first
    assert_equal original_id, updated_tax_class.id, "Tax class should be reused, not recreated"
    assert updated_tax_class.net > 0, "Tax class should have updated net amount"
  end

  test "should update tax values when replacing customer from national to EU" do
    # Start with a national customer (20% tax)
    invoice = Invoice.create!(
      customer: customers(:good_national),
      project: projects(:test_project),
      cust_reference: "TAX_TEST"
    )

    # Add an invoice line
    invoice.invoice_lines.create!(
      type: "item",
      title: "Test Product",
      description: "A test product",
      rate: 100.0,
      quantity: 2.0,
      sales_tax_product_class: sales_tax_product_classes(:standard),
      position: 1
    )

    # Update with national customer to calculate initial taxes
    patch invoice_url(invoice), params: { invoice: { cust_reference: "TAX_TEST_NATIONAL" } }
    invoice.reload

    # Verify national customer has 20% tax
    assert_equal 200.0, invoice.sum_net, "Net should be 200.0"
    assert_equal 240.0, invoice.sum_total, "Total should be 240.0 (200 + 20% tax)"
    tax_class = invoice.invoice_tax_classes.first
    assert_equal 20.0, tax_class.rate, "Tax rate should be 20%"
    assert_equal 40.0, tax_class.value, "Tax value should be 40.0"

    # Now change to EU customer (0% tax)
    patch invoice_url(invoice), params: {
      invoice: {
        customer_id: customers(:good_eu).id,
        cust_reference: "TAX_TEST_EU"
      }
    }
    invoice.reload

    # Verify EU customer has 0% tax
    assert_equal 200.0, invoice.sum_net, "Net should remain 200.0"
    assert_equal 200.0, invoice.sum_total, "Total should be 200.0 (no tax)"
    tax_class = invoice.invoice_tax_classes.first
    assert_equal 0.0, tax_class.rate, "Tax rate should be 0%"
    assert_equal 0.0, tax_class.value, "Tax value should be 0.0"
  end

  # Published-invoice guards (edit/update/destroy/preview/publish) live in
  # test/controllers/concerns/publishable_document_test.rb.

  test "destroying a draft invoice unlinks its delivery note" do
    invoice = create_draft_invoice(cust_reference: "LINKED")
    note = delivery_notes(:published_delivery_note)
    note.update!(invoice: invoice)

    assert_difference("Invoice.count", -1) do
      delete invoice_url(invoice)
    end

    assert_nil note.reload.invoice_id
  end

  test "import_lines returns invoice lines parsed from the uploaded CSV" do
    invoice = create_draft_invoice(cust_reference: "IMPORT")

    post import_lines_invoice_url(invoice),
      params: { file: fixture_file_upload("tyme_sample.csv", "text/csv") }

    assert_response :success
    lines = JSON.parse(response.body)["lines"]
    assert_equal 3, lines.length
    assert_equal "IT Consulting per hour: Project Alpha", lines.first["title"]
    assert_equal "1.25", lines.first["quantity"]
  end

  test "import_lines returns a 422 error when no file is uploaded" do
    invoice = create_draft_invoice(cust_reference: "IMPORT")

    post import_lines_invoice_url(invoice)

    assert_response :unprocessable_content
    assert JSON.parse(response.body)["error"].present?
  end
end
