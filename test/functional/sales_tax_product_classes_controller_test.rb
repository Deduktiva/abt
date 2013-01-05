require 'test_helper'

class SalesTaxProductClassesControllerTest < ActionController::TestCase
  setup do
    @sales_tax_product_class = sales_tax_product_classes(:one)
  end

  test "should get index" do
    get :index
    assert_response :success
    assert_not_nil assigns(:sales_tax_product_classes)
  end

  test "should get new" do
    get :new
    assert_response :success
  end

  test "should create sales_tax_product_class" do
    assert_difference('SalesTaxProductClass.count') do
      post :create, sales_tax_product_class: { indicator_code: @sales_tax_product_class.indicator_code, name: @sales_tax_product_class.name }
    end

    assert_redirected_to sales_tax_product_class_path(assigns(:sales_tax_product_class))
  end

  test "should show sales_tax_product_class" do
    get :show, id: @sales_tax_product_class
    assert_response :success
  end

  test "should get edit" do
    get :edit, id: @sales_tax_product_class
    assert_response :success
  end

  test "should update sales_tax_product_class" do
    put :update, id: @sales_tax_product_class, sales_tax_product_class: { indicator_code: @sales_tax_product_class.indicator_code, name: @sales_tax_product_class.name }
    assert_redirected_to sales_tax_product_class_path(assigns(:sales_tax_product_class))
  end

  test "should destroy sales_tax_product_class" do
    assert_difference('SalesTaxProductClass.count', -1) do
      delete :destroy, id: @sales_tax_product_class
    end

    assert_redirected_to sales_tax_product_classes_path
  end
end
