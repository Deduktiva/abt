require "test_helper"

# LineItem concern (title/type/inheritance_column/is_item?/TYPE_OPTIONS) is
# covered by InvoiceLineTest. Only DN-specific quantity validation lives here.
class DeliveryNoteLineTest < ActiveSupport::TestCase
  test "should require quantity for item type" do
    line = DeliveryNoteLine.new(title: "Test", type: "item", delivery_note: delivery_notes(:published_delivery_note))
    assert_not line.valid?
    assert_includes line.errors[:quantity], "can't be blank"
  end

  test "should not require quantity for non-item types" do
    line = DeliveryNoteLine.new(title: "Test", type: "text", delivery_note: delivery_notes(:published_delivery_note))
    assert line.valid?
  end
end
