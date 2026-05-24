require "test_helper"

class SalesTaxProductClassTest < ActiveSupport::TestCase
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
