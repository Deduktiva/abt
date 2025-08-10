require "test_helper"

class DeliveryNoteLineTest < ActiveSupport::TestCase
  test "should require title" do
    line = DeliveryNoteLine.new
    assert_not line.valid?
    assert_includes line.errors[:title], "can't be blank"
  end

  test "should require type" do
    line = DeliveryNoteLine.new(title: "Test")
    assert_not line.valid?
    assert_includes line.errors[:type], "can't be blank"
  end

  test "should validate type is in TYPE_OPTIONS" do
    line = DeliveryNoteLine.new(title: "Test", type: "invalid_type")
    assert_not line.valid?
    assert_includes line.errors[:type], "is not included in the list"
  end

  test "should require quantity for item type" do
    line = DeliveryNoteLine.new(title: "Test", type: "item", delivery_note: delivery_notes(:published_delivery_note))
    assert_not line.valid?
    assert_includes line.errors[:quantity], "can't be blank"
  end

  test "should not require quantity for non-item types" do
    line = DeliveryNoteLine.new(title: "Test", type: "text", delivery_note: delivery_notes(:published_delivery_note))
    assert line.valid?
  end

  test "is_item? returns true for item type" do
    line = delivery_note_lines(:item_line)
    assert line.is_item?
  end

  test "is_item? returns false for non-item types" do
    line = delivery_note_lines(:text_line)
    assert_not line.is_item?
  end

  test "TYPE_OPTIONS contains valid types" do
    expected_types = %w[text item subheading plain]
    assert_equal expected_types.sort, DeliveryNoteLine::TYPE_OPTIONS.values.sort
  end
end
