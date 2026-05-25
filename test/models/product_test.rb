require "test_helper"

class ProductTest < ActiveSupport::TestCase
  test "belongs to a sales_tax_product_class" do
    product = Product.new(sales_tax_product_class: sales_tax_product_classes(:standard))
    assert_equal sales_tax_product_classes(:standard), product.sales_tax_product_class
  end

  test "sales_tax_rates returns rates of the product class" do
    product = Product.new(sales_tax_product_class: sales_tax_product_classes(:standard))
    assert_includes product.sales_tax_rates, sales_tax_rates(:national_standard)
    assert_includes product.sales_tax_rates, sales_tax_rates(:eu_standard)
  end
end
