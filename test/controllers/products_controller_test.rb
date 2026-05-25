require "test_helper"

class ProductsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get products_url
    assert_response :success
  end

  test "should get new" do
    get new_product_url
    assert_response :success
  end

  test "new product form marks required fields and lets the browser validate them" do
    get new_product_url
    assert_response :success

    assert_select "form#new_product:not([novalidate])"

    assert_select "input#product_title[required]"
    assert_select "input#product_rate[required]"
    assert_select "select#product_sales_tax_product_class_id[required]"

    assert_select "label.required[for='product_title']"
    assert_select "label.required[for='product_rate']"
    assert_select "label.required[for='product_sales_tax_product_class_id']"
  end
end
