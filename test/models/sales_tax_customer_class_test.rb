require "test_helper"

class SalesTaxCustomerClassTest < ActiveSupport::TestCase
  test "requires name" do
    klass = SalesTaxCustomerClass.new
    assert_not klass.valid?
    assert_includes klass.errors[:name], "can't be blank"
  end

  test "destroy is blocked when sales_tax_rates reference the class" do
    klass = SalesTaxCustomerClass.create!(name: "Test Region With Rate")
    SalesTaxRate.create!(
      sales_tax_customer_class: klass,
      sales_tax_product_class: sales_tax_product_classes(:standard),
      rate: 5
    )
    assert_raises(ActiveRecord::DeleteRestrictionError) { klass.destroy }
  end

  test "destroy is blocked when customers reference the class" do
    klass = SalesTaxCustomerClass.create!(name: "Test Region")
    Customer.create!(
      matchcode: "STC_TEST",
      name: "Test Customer",
      sales_tax_customer_class: klass,
      language: languages(:english),
      team: teams(:default)
    )
    assert_raises(ActiveRecord::DeleteRestrictionError) { klass.destroy }
  end

  test "destroy succeeds when no rates or customers reference the class" do
    klass = SalesTaxCustomerClass.create!(name: "Test Region")
    assert klass.destroy
  end
end
