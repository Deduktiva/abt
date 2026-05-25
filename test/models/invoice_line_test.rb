require "test_helper"

class InvoiceLineTest < ActiveSupport::TestCase
  test "requires title" do
    line = InvoiceLine.new(type: "item", rate: 10, quantity: 1, invoice: invoices(:draft_invoice))
    assert_not line.valid?
    assert_includes line.errors[:title], "can't be blank"
  end

  test "requires type" do
    line = InvoiceLine.new(title: "x", invoice: invoices(:draft_invoice))
    assert_not line.valid?
    assert_includes line.errors[:type], "can't be blank"
  end

  test "type must be one of the allowed values" do
    line = InvoiceLine.new(title: "x", type: "bogus", invoice: invoices(:draft_invoice))
    assert_not line.valid?
    assert_includes line.errors[:type], "is not included in the list"
  end

  test "item lines require rate and quantity" do
    line = InvoiceLine.new(title: "x", type: "item", invoice: invoices(:draft_invoice))
    assert_not line.valid?
    assert_includes line.errors[:rate], "can't be blank"
    assert_includes line.errors[:quantity], "can't be blank"
  end

  test "non-item lines do not require rate or quantity" do
    [ "text", "subheading", "plain" ].each do |t|
      line = InvoiceLine.new(title: "x", type: t, invoice: invoices(:draft_invoice))
      assert line.valid?, "expected type=#{t} to be valid without rate/quantity"
    end
  end

  test "before_save clears rate, quantity, product_class on non-item lines and zeroes amount" do
    line = InvoiceLine.create!(
      invoice: invoices(:draft_invoice),
      title: "Notes",
      type: "text",
      rate: 99,
      quantity: 5,
      sales_tax_product_class: sales_tax_product_classes(:standard)
    )
    assert_nil line.rate
    assert_nil line.quantity
    assert_nil line.sales_tax_product_class_id
    # clear_non_item_fields nils amount, then calculate_amount runs and sets it to 0
    assert_equal 0, line.amount
  end

  test "calculate_amount sets amount = rate * quantity for item lines" do
    line = InvoiceLine.new(
      invoice: invoices(:draft_invoice),
      title: "Widget",
      type: "item",
      rate: 12.5,
      quantity: 4
    )
    line.calculate_amount
    assert_equal 50.0, line.amount
  end

  test "calculate_amount sets amount = 0 for non-item lines" do
    line = InvoiceLine.new(
      invoice: invoices(:draft_invoice),
      title: "Section",
      type: "subheading"
    )
    line.calculate_amount
    assert_equal 0, line.amount
  end

  test "is_item? is only true for type=item" do
    assert InvoiceLine.new(type: "item").is_item?
    assert_not InvoiceLine.new(type: "text").is_item?
    assert_not InvoiceLine.new(type: "subheading").is_item?
    assert_not InvoiceLine.new(type: "plain").is_item?
  end

  test "inheritance_column is type_ to avoid STI collision with type column" do
    assert_equal "type_", InvoiceLine.inheritance_column
  end
end
