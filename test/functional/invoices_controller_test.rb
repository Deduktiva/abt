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

end
