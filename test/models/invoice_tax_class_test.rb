require "test_helper"

class InvoiceTaxClassTest < ActiveSupport::TestCase
  def build_tax_class(rate: 20)
    InvoiceTaxClass.new(
      invoice: invoices(:draft_invoice),
      sales_tax_product_class: sales_tax_product_classes(:standard),
      name: "Standard",
      indicator_code: "STD",
      rate: rate,
      net: 0,
      total: 0
    )
  end

  test "requires net" do
    itc = build_tax_class
    itc[:net] = nil
    assert_not itc.valid?
    assert_includes itc.errors[:net], "can't be blank"
  end

  test "requires rate" do
    itc = build_tax_class
    itc[:rate] = nil
    assert_not itc.valid?
    assert_includes itc.errors[:rate], "can't be blank"
  end

  test "net= rounds tax value to cents with total = net + value" do
    itc = build_tax_class(rate: 8.25)
    itc.net = 33.33
    assert_equal BigDecimal("2.75"), itc.value
    assert_equal BigDecimal("36.08"), itc.total
    assert_equal itc.net + itc.value, itc.total
  end

  test "net= recomputes value and total on reassignment" do
    itc = build_tax_class
    itc.net = 100
    itc.net = 50
    assert_equal 50, itc.net
    assert_in_delta 10.0, itc.value, 0.0001
    assert_in_delta 60.0, itc.total, 0.0001
  end

  test "net= with rate=0 leaves total equal to net" do
    itc = build_tax_class(rate: 0)
    itc.net = 75
    assert_equal 75, itc.net
    assert_in_delta 0.0, itc.value, 0.0001
    assert_in_delta 75.0, itc.total, 0.0001
  end
end
