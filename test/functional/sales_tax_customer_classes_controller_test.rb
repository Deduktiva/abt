require 'test_helper'

class SalesTaxCustomerClassesControllerTest < ActionController::TestCase
  setup do
    @sales_tax_customer_class = sales_tax_customer_classes(:one)
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:sales_tax_customer_classes)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create sales_tax_customer_class" do
    assert_difference('SalesTaxCustomerClass.count') do
      post :create, sales_tax_customer_class: { invoice_note: @sales_tax_customer_class.invoice_note, name: @sales_tax_customer_class.name }
    end

    assert_redirected_to sales_tax_customer_class_path(assigns(:sales_tax_customer_class))
  end

  test "should show sales_tax_customer_class" do
    get :show, id: @sales_tax_customer_class
    assert_response :success
  end

  test "should get edit" do
    get :edit, id: @sales_tax_customer_class
    assert_response :success
  end

  test "should update sales_tax_customer_class" do
    put :update, id: @sales_tax_customer_class, sales_tax_customer_class: { invoice_note: @sales_tax_customer_class.invoice_note, name: @sales_tax_customer_class.name }
    assert_redirected_to sales_tax_customer_class_path(assigns(:sales_tax_customer_class))
  end

  test "should destroy sales_tax_customer_class" do
    assert_difference('SalesTaxCustomerClass.count', -1) do
      delete :destroy, id: @sales_tax_customer_class
    end

    assert_redirected_to sales_tax_customer_classes_path
  end
end
