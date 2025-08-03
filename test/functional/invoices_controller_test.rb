require 'test_helper'

class InvoicesControllerTest < ActionController::TestCase
  test "should get index" do
    get :index
    assert_response :success
  end

  test "should get index with year filter" do
    # Create invoices in different years
    invoice_2023 = Invoice.create!(
      customer: customers(:good_eu),
      project: projects(:test_project),
      cust_reference: "2023-TEST",
      date: Date.new(2023, 6, 15)
    )

    invoice_2024 = Invoice.create!(
      customer: customers(:good_eu),
      project: projects(:test_project),
      cust_reference: "2024-TEST",
      date: Date.new(2024, 6, 15)
    )

    # Test current year (default)
    get :index
    assert_response :success
    assert_select '.year-pagination'

    # Test specific year filter
    get :index, params: { year: 2023 }
    assert_response :success
    # Verify the page contains the 2023 invoice reference but not 2024
    assert_select 'td', text: '2023-TEST'
    assert_select 'td', text: '2024-TEST', count: 0
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create invoice" do
    assert_difference('Invoice.count') do
      post :create, params: {
        invoice: {
          customer_id: customers(:good_eu).id,
          project_id: projects(:test_project).id,
          cust_reference: "REF123",
          cust_order: "ORDER456",
          prelude: "Test invoice"
        }
      }
    end
    assert_response :redirect
  end

  test "should show invoice" do
    invoice = Invoice.create!(
      customer: customers(:good_eu),
      project: projects(:test_project),
      cust_reference: "TEST"
    )
    get :show, params: { id: invoice.id }
    assert_response :success
  end

  test "should show booked invoice with tax classes" do
    invoice = Invoice.create!(
      customer: customers(:good_eu),
      project: projects(:test_project),
      cust_reference: "TEST",
      published: true,
      document_number: "INV-2024-001",
      date: Date.current,
      sum_net: 200.0,
      sum_total: 238.0
    )

    # Add invoice lines
    invoice.invoice_lines.create!(
      type: 'item',
      title: 'Test Product',
      description: 'A test product',
      rate: 100.0,
      quantity: 2.0,
      sales_tax_product_class: sales_tax_product_classes(:standard),
      position: 1
    )

    # Add tax classes
    tax_class = invoice.invoice_tax_classes.build(
      sales_tax_product_class: sales_tax_product_classes(:standard),
      rate: 19.0,
      value: 38.0,
      total: 238.0
    )
    tax_class.net = 200.0
    tax_class.save!

    get :show, params: { id: invoice.id }
    assert_response :success
    assert_select '.invoice-document'
    assert_select 'table.table-bordered'
    assert_select '.badge.bg-success', text: 'Booked'
  end

  test "should show draft invoice prompting for test booking" do
    invoice = Invoice.create!(
      customer: customers(:good_eu),
      project: projects(:test_project),
      cust_reference: "TEST_DRAFT",
      sum_net: 100.0,
      sum_total: 0.0  # Draft invoices have sum_total = 0
    )

    # Add invoice line with tax class
    invoice.invoice_lines.create!(
      type: 'item',
      title: 'Test Product',
      description: 'A test product',
      rate: 100.0,
      quantity: 1.0,
      sales_tax_product_class: sales_tax_product_classes(:standard),
      position: 1
    )

    get :show, params: { id: invoice.id }
    assert_response :success
    assert_select '.badge.bg-warning', text: 'Draft'
    # Should show prompt to use test booking for total calculation
    assert_select 'em', text: 'Use "Test Booking" to calculate'
  end

  test "should get edit" do
    invoice = Invoice.create!(
      customer: customers(:good_eu),
      project: projects(:test_project),
      cust_reference: "TEST"
    )
    get :edit, params: { id: invoice.id }
    assert_response :success
  end

  test "should get edit with existing lines" do
    invoice = Invoice.create!(
      customer: customers(:good_eu),
      project: projects(:test_project),
      cust_reference: "TEST"
    )

    # Add some invoice lines to test the HAML template rendering
    invoice.invoice_lines.create!(
      type: 'item',
      title: 'Test Product',
      description: 'A test product',
      rate: 100.0,
      quantity: 2.0,
      sales_tax_product_class: sales_tax_product_classes(:standard),
      position: 1
    )

    invoice.invoice_lines.create!(
      type: 'text',
      title: 'Note',
      description: 'Additional information',
      position: 2
    )

    get :edit, params: { id: invoice.id }
    assert_response :success
  end

  test "should update invoice with nested attributes" do
    invoice = Invoice.create!(
      customer: customers(:good_eu),
      project: projects(:test_project),
      cust_reference: "TEST"
    )

    put :update, params: {
      id: invoice.id,
      invoice: {
        cust_reference: "UPDATED_REF",
        invoice_lines_attributes: {
          "0" => {
            type: "item",
            title: "Test Product",
            description: "A test product",
            rate: "100.00",
            quantity: "2",
            position: "1",
            sales_tax_product_class_id: ""
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

    assert_redirected_to invoice_path(invoice)
    invoice.reload
    assert_equal "UPDATED_REF", invoice.cust_reference
    assert_equal 2, invoice.invoice_lines.count
    assert_equal "Test Product", invoice.invoice_lines.first.title

    # Verify totals are calculated correctly
    invoice.reload
    assert_in_delta 200.0, invoice.sum_net, 0.01  # 100.00 * 2
    assert_in_delta 0.0, invoice.sum_total, 0.01  # For draft invoices, total stays 0
  end

  test "should handle test booking with saving changes" do
    invoice = Invoice.create!(
      customer: customers(:good_eu),
      project: projects(:test_project),
      cust_reference: "TEST"
    )

    # Add an invoice line to test booking
    invoice.invoice_lines.create!(
      type: 'item',
      title: 'Test Product',
      description: 'A test product',
      rate: 100.0,
      quantity: 2.0,
      sales_tax_product_class: sales_tax_product_classes(:standard),
      position: 1
    )

    post :test_booking, params: {
      id: invoice.id,
      invoice: {
        cust_reference: "UPDATED_FOR_TEST_BOOKING",
        invoice_lines_attributes: {
          "0" => {
            id: invoice.invoice_lines.first.id,
            type: "item",
            title: "Updated Test Product",
            description: "Updated description",
            rate: "150.00",
            quantity: "3",
            position: "1",
            sales_tax_product_class_id: sales_tax_product_classes(:standard).id
          }
        }
      }
    }

    assert_redirected_to invoice_path(invoice)
    invoice.reload
    assert_equal "UPDATED_FOR_TEST_BOOKING", invoice.cust_reference
    assert_equal "Updated Test Product", invoice.invoice_lines.first.title
    assert_equal 150.0, invoice.invoice_lines.first.rate
    assert_equal 3.0, invoice.invoice_lines.first.quantity

    # Verify that test booking calculated and persisted totals
    assert invoice.sum_net > 0, "sum_net should be calculated"
    assert invoice.sum_total > 0, "sum_total should be calculated and persisted"
    assert invoice.invoice_tax_classes.any?, "tax classes should be created"
  end

  test "should handle test booking with validation errors" do
    invoice = Invoice.create!(
      customer: customers(:good_eu),
      project: projects(:test_project),
      cust_reference: "TEST"
    )

    post :test_booking, params: {
      id: invoice.id,
      invoice: {
        customer_id: nil, # This should cause validation error
        cust_reference: "INVALID"
      }
    }

    assert_response :success
  end

  test "should reject test booking for published invoices" do
    invoice = Invoice.create!(
      customer: customers(:good_eu),
      project: projects(:test_project),
      cust_reference: "TEST",
      published: true
    )

    post :test_booking, params: { id: invoice.id }

    assert_redirected_to invoice_path(invoice)
    assert_match /Published invoices can not be modified/, flash[:error]
  end

  test "should reset totals when draft invoice is modified after test booking" do
    invoice = Invoice.create!(
      customer: customers(:good_eu),
      project: projects(:test_project),
      cust_reference: "TEST",
      sum_net: 200.0,
      sum_total: 238.0  # Simulate after test booking
    )

    # Add tax classes to simulate test booking results
    invoice.invoice_tax_classes.create!(
      sales_tax_product_class: sales_tax_product_classes(:standard),
      rate: 19.0,
      net: 200.0,
      value: 38.0,
      total: 238.0
    )

    # Modify the invoice
    put :update, params: {
      id: invoice.id,
      invoice: {
        cust_reference: "MODIFIED_REF",
        invoice_lines_attributes: {
          "0" => {
            type: "item",
            title: "New Product",
            rate: "50.00",
            quantity: "1",
            position: "1"
          }
        }
      }
    }

    assert_redirected_to invoice_path(invoice)
    invoice.reload

    # Verify totals are reset
    assert_equal 50.0, invoice.sum_net  # New calculation
    assert_equal 0.0, invoice.sum_total  # Reset to 0
    assert_equal 0, invoice.invoice_tax_classes.count  # Tax classes cleared
  end

  test "should handle test booking from show page without form params" do
    invoice = Invoice.create!(
      customer: customers(:good_eu),
      project: projects(:test_project),
      cust_reference: "TEST"
    )

    # Add an invoice line
    invoice.invoice_lines.create!(
      type: 'item',
      title: 'Test Product',
      description: 'A test product',
      rate: 100.0,
      quantity: 2.0,
      sales_tax_product_class: sales_tax_product_classes(:standard),
      position: 1
    )

    post :test_booking, params: { id: invoice.id }

    assert_redirected_to invoice_path(invoice)
    invoice.reload

    # Verify that test booking calculated and persisted totals
    assert invoice.sum_net > 0, "sum_net should be calculated"
    assert invoice.sum_total > 0, "sum_total should be calculated and persisted"
    assert invoice.invoice_tax_classes.any?, "tax classes should be created"
  end

  test "should reuse existing tax classes during test booking optimization" do
    invoice = Invoice.create!(
      customer: customers(:good_eu),
      project: projects(:test_project),
      cust_reference: "TEST"
    )

    # Add an invoice line
    invoice.invoice_lines.create!(
      type: 'item',
      title: 'Test Product',
      description: 'A test product',
      rate: 100.0,
      quantity: 2.0,
      sales_tax_product_class: sales_tax_product_classes(:standard),
      position: 1
    )

    # Run test booking first time to create tax classes
    post :test_booking, params: { id: invoice.id }
    invoice.reload

    # Remember the tax class ID
    original_tax_class = invoice.invoice_tax_classes.first
    original_id = original_tax_class.id

    # Modify the invoice to trigger recalculation
    invoice.invoice_lines.first.update!(quantity: 3.0)

    # Run test booking again - should reuse existing tax class
    post :test_booking, params: { id: invoice.id }
    invoice.reload

    # Verify the tax class was updated, not recreated
    updated_tax_class = invoice.invoice_tax_classes.first
    assert_equal original_id, updated_tax_class.id, "Tax class should be reused, not recreated"
    assert updated_tax_class.net > 0, "Tax class should have updated net amount"
  end

end
