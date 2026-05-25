require "test_helper"

class SalesTaxRateTest < ActiveSupport::TestCase
  def setup
    @customer_class = SalesTaxCustomerClass.create!(name: "Test Region")
    @product_class = SalesTaxProductClass.create!(name: "Test Product Class", indicator_code: "TPC")
  end

  test "requires rate" do
    rate = SalesTaxRate.new(
      sales_tax_customer_class: @customer_class,
      sales_tax_product_class: @product_class
    )
    assert_not rate.valid?
    assert_includes rate.errors[:rate], "can't be blank"
  end

  test "requires sales_tax_customer_class" do
    rate = SalesTaxRate.new(sales_tax_product_class: @product_class, rate: 10)
    assert_not rate.valid?
    assert_includes rate.errors[:sales_tax_customer_class], "can't be blank"
  end

  test "requires sales_tax_product_class" do
    rate = SalesTaxRate.new(sales_tax_customer_class: @customer_class, rate: 10)
    assert_not rate.valid?
    assert_includes rate.errors[:sales_tax_product_class], "can't be blank"
  end

  test "rate accepts 0, intermediate values, and 100" do
    [ 0, 10, 20, 100 ].each do |valid_rate|
      rate = SalesTaxRate.new(
        sales_tax_customer_class: @customer_class,
        sales_tax_product_class: @product_class,
        rate: valid_rate
      )
      assert rate.valid?, "expected rate=#{valid_rate} to be valid"
    end
  end

  test "rate rejects values outside 0..100" do
    [ -1, 101, 200 ].each do |invalid_rate|
      rate = SalesTaxRate.new(
        sales_tax_customer_class: @customer_class,
        sales_tax_product_class: @product_class,
        rate: invalid_rate
      )
      assert_not rate.valid?, "expected rate=#{invalid_rate} to be invalid"
      assert_includes rate.errors[:rate], "is not included in the list"
    end
  end
end
