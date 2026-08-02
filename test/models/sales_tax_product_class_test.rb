require "test_helper"

class SalesTaxProductClassTest < ActiveSupport::TestCase
  test "indicator_code must be unique" do
    klass = SalesTaxProductClass.new(name: "Duplicate Code", indicator_code: sales_tax_product_classes(:standard).indicator_code)
    assert_not klass.valid?
    assert_includes klass.errors[:indicator_code], "has already been taken"
  end

  test "name must be unique" do
    klass = SalesTaxProductClass.new(name: sales_tax_product_classes(:standard).name, indicator_code: "DUP")
    assert_not klass.valid?
    assert_includes klass.errors[:name], "has already been taken"
  end

  test "database rejects a duplicate indicator_code that skips validation" do
    klass = SalesTaxProductClass.new(name: "Bypass", indicator_code: sales_tax_product_classes(:standard).indicator_code)
    assert_raises(ActiveRecord::RecordNotUnique) { klass.save!(validate: false) }
  end

  test "default returns the row flagged as default" do
    assert_equal sales_tax_product_classes(:standard), SalesTaxProductClass.default
  end

  test "default returns nil when no row is flagged" do
    SalesTaxProductClass.update_all(is_default: false)
    assert_nil SalesTaxProductClass.default
  end

  test "setting a new default unsets the previous default" do
    previous_default = sales_tax_product_classes(:standard)
    assert previous_default.is_default?

    new_default = SalesTaxProductClass.create!(name: "Reduced", indicator_code: "RED", is_default: true)

    assert SalesTaxProductClass.find(new_default.id).is_default?
    assert_not previous_default.reload.is_default?
  end

  test "leaving is_default unchanged on save does not touch siblings" do
    other = SalesTaxProductClass.create!(name: "Other", indicator_code: "OTH", is_default: false)
    default = sales_tax_product_classes(:standard)

    other.update!(name: "Other Renamed")

    assert default.reload.is_default?
  end
end
