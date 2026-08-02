require "test_helper"

class SalesTaxProductClassesControllerTest < ActionDispatch::IntegrationTest
  test "destroy removes a product class that has no rates" do
    product_class = SalesTaxProductClass.create!(name: "Reduced", indicator_code: "RED")

    assert_difference("SalesTaxProductClass.count", -1) do
      delete sales_tax_product_class_url(product_class)
    end
    assert_redirected_to sales_tax_product_classes_url
  end

  test "destroy reports an error instead of raising when rates reference the product class" do
    product_class = sales_tax_product_classes(:standard)

    assert_no_difference("SalesTaxProductClass.count") do
      delete sales_tax_product_class_url(product_class)
    end
    assert_redirected_to sales_tax_product_classes_url
    assert_match(/sales tax rates/i, flash[:alert])
  end
end
