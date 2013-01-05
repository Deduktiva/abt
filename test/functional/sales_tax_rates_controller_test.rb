require 'test_helper'

class SalesTaxRatesControllerTest < ActionController::TestCase
  setup do
    @sales_tax_rate = sales_tax_rates(:one)
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:sales_tax_rates)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create sales_tax_rate" do
    assert_difference('SalesTaxRate.count') do
      post :create, sales_tax_rate: { rate: @sales_tax_rate.rate, sales_tax_customer_class_id: @sales_tax_rate.sales_tax_customer_class_id, sales_tax_product_class_id: @sales_tax_rate.sales_tax_product_class_id }
    end

    assert_redirected_to sales_tax_rate_path(assigns(:sales_tax_rate))
  end

  test "should show sales_tax_rate" do
    get :show, id: @sales_tax_rate
    assert_response :success
  end

  test "should get edit" do
    get :edit, id: @sales_tax_rate
    assert_response :success
  end

  test "should update sales_tax_rate" do
    put :update, id: @sales_tax_rate, sales_tax_rate: { rate: @sales_tax_rate.rate, sales_tax_customer_class_id: @sales_tax_rate.sales_tax_customer_class_id, sales_tax_product_class_id: @sales_tax_rate.sales_tax_product_class_id }
    assert_redirected_to sales_tax_rate_path(assigns(:sales_tax_rate))
  end

  test "should destroy sales_tax_rate" do
    assert_difference('SalesTaxRate.count', -1) do
      delete :destroy, id: @sales_tax_rate
    end

    assert_redirected_to sales_tax_rates_path
  end
end
