require 'test_helper'

class DeliveryNotePdfTest < ActionDispatch::IntegrationTest
  setup do
    @issuer = issuer_companies(:one)
    @customer_en = customers(:good_eu)  # English language customer
    @customer_de = customers(:good_national)  # German language customer
    @project = projects(:one)
  end

  test "generates PDF for delivery note with English customer" do
    delivery_note = DeliveryNote.create!(
      customer: @customer_en,
      project: @project,
      date: Date.new(2025, 8, 15),
      delivery_start_date: Date.new(2025, 8, 1),
      delivery_end_date: Date.new(2025, 8, 31),
      cust_reference: "EN-REF-001",
      cust_order: "EN-ORDER-001",
      prelude: "Thank you for your business."
    )

    # Add some delivery note lines
    delivery_note.delivery_note_lines.create!(
      type: "item",
      title: "Software Development",
      description: "Custom application development",
      quantity: 40,
      position: 1
    )

    delivery_note.delivery_note_lines.create!(
      type: "text",
      title: "Additional Notes",
      description: "Project completed successfully.",
      position: 2
    )

    # Test PDF generation
    get preview_delivery_note_path(delivery_note)
    assert_response :success
    assert_valid_pdf_response
  end

  test "generates PDF for delivery note with German customer" do
    delivery_note = DeliveryNote.create!(
      customer: @customer_de,
      project: @project,
      date: Date.new(2025, 8, 15),
      delivery_start_date: Date.new(2025, 8, 1),
      delivery_end_date: Date.new(2025, 8, 31),
      cust_reference: "DE-REF-001",
      cust_order: "DE-ORDER-001",
      prelude: "Vielen Dank für Ihr Vertrauen."
    )

    # Add some delivery note lines
    delivery_note.delivery_note_lines.create!(
      type: "item",
      title: "Softwareentwicklung",
      description: "Individuelle Anwendungsentwicklung",
      quantity: 40,
      position: 1
    )

    delivery_note.delivery_note_lines.create!(
      type: "subheading",
      title: "Zusätzliche Informationen",
      position: 2
    )

    delivery_note.delivery_note_lines.create!(
      type: "text",
      title: "Projektnotizen",
      description: "Projekt erfolgreich abgeschlossen.",
      position: 3
    )

    # Test PDF generation
    get preview_delivery_note_path(delivery_note)
    assert_response :success
    assert_valid_pdf_response
  end

  test "delivery note PDF includes language-specific content" do
    # Test that the DeliveryNoteRenderer correctly passes language to XML
    delivery_note_en = DeliveryNote.create!(
      customer: @customer_en,
      project: @project,
      date: Date.new(2025, 8, 15),
      delivery_start_date: Date.new(2025, 8, 1),
      prelude: "English prelude"
    )

    delivery_note_de = DeliveryNote.create!(
      customer: @customer_de,
      project: @project,
      date: Date.new(2025, 8, 15),
      delivery_start_date: Date.new(2025, 8, 1),
      prelude: "German prelude"
    )

    # Test XML generation includes correct language
    renderer_en = DeliveryNoteRenderer.new(delivery_note_en, @issuer)
    xml_en = renderer_en.emit_xml(nil)
    assert_includes xml_en, '<language>en</language>', "English delivery note should include language en"

    renderer_de = DeliveryNoteRenderer.new(delivery_note_de, @issuer)
    xml_de = renderer_de.emit_xml(nil)
    assert_includes xml_de, '<language>de</language>', "German delivery note should include language de"
  end

  test "delivery note XML structure is correct" do
    delivery_note = DeliveryNote.create!(
      customer: @customer_en,
      project: @project,
      date: Date.new(2025, 8, 15),
      delivery_start_date: Date.new(2025, 8, 1),
      delivery_end_date: Date.new(2025, 8, 31),
      cust_reference: "XML-TEST-REF",
      cust_order: "XML-TEST-ORDER",
      prelude: "Test prelude content"
    )

    delivery_note.delivery_note_lines.create!(
      type: "item",
      title: "Test Item",
      description: "Test description",
      quantity: 5,
      position: 1
    )

    renderer = DeliveryNoteRenderer.new(delivery_note, @issuer)
    xml = renderer.emit_xml(nil)

    # Verify key XML elements
    assert_includes xml, '<language>en</language>'
    assert_includes xml, '<prelude>Test prelude content</prelude>'
    assert_includes xml, '<reference>XML-TEST-REF</reference>'
    assert_includes xml, '<order-no>XML-TEST-ORDER</order-no>'
    assert_includes xml, '<delivery-timeframe>August 2025</delivery-timeframe>'
    assert_includes xml, '<item>'
    assert_includes xml, '<title>Test Item</title>'
    assert_includes xml, '<description>Test description</description>'
    assert_includes xml, '<quantity>5.0</quantity>'
  end

  private

  def assert_valid_pdf_response
    assert_equal 'application/pdf', response.content_type
    assert response.body.start_with?('%PDF'), "Response should be a valid PDF file"
  end
end
