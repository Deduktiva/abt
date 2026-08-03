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

  test "destroy is blocked when products reference the class" do
    klass = SalesTaxProductClass.create!(name: "Product Only", indicator_code: "PRO")
    Product.create!(title: "Widget", rate: 10, sales_tax_product_class: klass)

    assert_not klass.destroy
    assert_includes klass.errors[:base], "Cannot delete product tax class that is used in products"
  end

  test "destroy is blocked when invoice tax classes reference the class" do
    klass = SalesTaxProductClass.create!(name: "Tax Class Only", indicator_code: "ITC")
    InvoiceTaxClass.create!(invoice: invoices(:published_invoice), sales_tax_product_class: klass,
                            name: klass.name, indicator_code: klass.indicator_code, rate: 20, net: 0)

    assert_not klass.destroy
    assert_includes klass.errors[:base], "Cannot delete product tax class that is used in invoices"
  end

  test "destroy is blocked when invoice lines reference the class" do
    klass = SalesTaxProductClass.create!(name: "Line Only", indicator_code: "LIN")
    invoice_lines(:draft_item).update!(sales_tax_product_class: klass)

    assert_not klass.destroy
    assert_includes klass.errors[:base], "Cannot delete product tax class that is used in invoices"
  end

  test "destroy is blocked when offer versions reference the class" do
    klass = SalesTaxProductClass.create!(name: "Offer Only", indicator_code: "OFF")
    offer_versions(:draft_offer_v1).update!(sales_tax_product_class: klass)

    assert_not klass.destroy
    assert_includes klass.errors[:base], "Cannot delete product tax class that is used in offers"
  end

  test "destroy is blocked for the default class even when nothing references it" do
    klass = SalesTaxProductClass.create!(name: "Sole Default", indicator_code: "SOL", is_default: true)

    assert_not klass.destroy
    assert_includes klass.errors[:base], "Cannot delete the default product tax class"
  end

  test "can_be_deleted? is false while the class is still referenced" do
    klass = SalesTaxProductClass.create!(name: "Referenced", indicator_code: "REF")
    Product.create!(title: "Widget", rate: 10, sales_tax_product_class: klass)

    assert_not klass.can_be_deleted?
  end

  test "can_be_deleted? is true for an unreferenced non-default class" do
    assert SalesTaxProductClass.create!(name: "Free", indicator_code: "FRE").can_be_deleted?
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
