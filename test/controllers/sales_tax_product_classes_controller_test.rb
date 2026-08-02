require "test_helper"

class SalesTaxProductClassesControllerTest < ActionDispatch::IntegrationTest
  test "destroy removes a product class that nothing references" do
    product_class = SalesTaxProductClass.create!(name: "Reduced", indicator_code: "RED")

    assert_difference("SalesTaxProductClass.count", -1) do
      delete sales_tax_product_class_url(product_class)
    end
    assert_redirected_to sales_tax_product_classes_url
  end

  test "destroy reports an error instead of raising when a rate references the product class" do
    product_class = SalesTaxProductClass.create!(name: "Rated", indicator_code: "RAT")
    SalesTaxRate.create!(sales_tax_customer_class: sales_tax_customer_classes(:national),
                         sales_tax_product_class: product_class, rate: 10)

    assert_no_difference("SalesTaxProductClass.count") do
      delete sales_tax_product_class_url(product_class)
    end
    assert_redirected_to sales_tax_product_classes_url
    assert_match(/sales tax rates/i, flash[:alert])
  end
end
