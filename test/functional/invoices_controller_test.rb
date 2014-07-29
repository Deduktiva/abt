require 'test_helper'

class InvoicesControllerTest < ActionController::TestCase
  setup do
    @invoice = invoices(:one)
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:invoices)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create invoice" do
    assert_difference('Invoice.count') do
      post :create, invoice: { attachment_id: @invoice.attachment_id, cust_reference: @invoice.cust_reference, customer_id: @invoice.customer_id, date: @invoice.date, document_number: @invoice.document_number, prelude: @invoice.prelude, project_id: @invoice.project_id, published: @invoice.published }
    end

    assert_redirected_to invoice_path(assigns(:invoice))
  end

  test "should show invoice" do
    get :show, id: @invoice
    assert_response :success
  end

  test "should get edit" do
    get :edit, id: @invoice
    assert_response :success
  end

  test "should update invoice" do
    put :update, id: @invoice, invoice: { attachment_id: @invoice.attachment_id, cust_reference: @invoice.cust_reference, customer_id: @invoice.customer_id, date: @invoice.date, document_number: @invoice.document_number, prelude: @invoice.prelude, project_id: @invoice.project_id, published: @invoice.published }
    assert_redirected_to invoice_path(assigns(:invoice))
  end

  test "should destroy invoice" do
    assert_difference('Invoice.count', -1) do
      delete :destroy, id: @invoice
    end

    assert_redirected_to invoices_path
  end
end
