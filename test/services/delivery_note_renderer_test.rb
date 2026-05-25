require "test_helper"

class DeliveryNoteRendererTest < ActiveSupport::TestCase
  setup do
    @delivery_note = delivery_notes(:draft_delivery_note)
    @issuer = issuer_companies(:one)
  end

  test "emits <supplier-no> when the customer has supplier_number set" do
    @delivery_note.customer.update!(supplier_number: "SUP-DN-7")
    xml = DeliveryNoteRenderer.new(@delivery_note, @issuer).emit_xml(nil)
    assert_match %r{<supplier-no>SUP-DN-7</supplier-no>}, xml
  end

  test "omits <supplier-no> when the customer has no supplier_number" do
    @delivery_note.customer.update!(supplier_number: nil)
    xml = DeliveryNoteRenderer.new(@delivery_note, @issuer).emit_xml(nil)
    assert_no_match %r{supplier-no}, xml
  end

  test "renders a valid PDF with and without supplier number (FOP smoke)" do
    @delivery_note.customer.update!(supplier_number: "ACME-VEND-7")
    pdf = DeliveryNoteRenderer.new(@delivery_note, @issuer).render
    assert pdf.start_with?("%PDF"), "expected a PDF (got #{pdf[0, 16].inspect})"

    @delivery_note.customer.update!(supplier_number: nil)
    pdf = DeliveryNoteRenderer.new(@delivery_note, @issuer).render
    assert pdf.start_with?("%PDF"), "expected a PDF (got #{pdf[0, 16].inspect})"
  end
end
