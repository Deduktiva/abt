require "test_helper"

class DeliveryNoteInvoiceConverterTest < ActiveSupport::TestCase
  test "a delivery note converted behind our back cannot convert again" do
    note = delivery_notes(:published_delivery_note)
    stale = DeliveryNote.find(note.id)
    DeliveryNoteInvoiceConverter.new(note).convert!

    assert_no_difference("Invoice.count") do
      assert_raises(DeliveryNoteInvoiceConverter::NotConvertible) do
        DeliveryNoteInvoiceConverter.new(stale).convert!
      end
    end
  end
end
