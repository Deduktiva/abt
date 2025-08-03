require 'test_helper'

class InvoicesControllerTest < ActionController::TestCase
  test "should get index" do
    get :index
    assert_response :success
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

    assert_redirected_to book_invoice_path(invoice)
    invoice.reload
    assert_equal "UPDATED_FOR_TEST_BOOKING", invoice.cust_reference
    assert_equal "Updated Test Product", invoice.invoice_lines.first.title
    assert_equal 150.0, invoice.invoice_lines.first.rate
    assert_equal 3.0, invoice.invoice_lines.first.quantity
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

end
