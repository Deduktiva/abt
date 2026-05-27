require "test_helper"

class InvoiceRendererTest < ActiveSupport::TestCase
  setup do
    @invoice = invoices(:draft_invoice)
    @invoice.save! # populates customer snapshot columns via update_customer
    @invoice.update_columns(due_date: Date.current + 30.days)
    @issuer = issuer_companies(:one)
  end

  test "emits <supplier-no> when invoice has customer_supplier_number" do
    @invoice.update_columns(customer_supplier_number: "SUP-123")
    xml = InvoiceRenderer.new(@invoice, @issuer).emit_xml(nil)
    assert_match %r{<supplier-no>SUP-123</supplier-no>}, xml
  end

  test "omits <supplier-no> when customer_supplier_number is blank" do
    @invoice.update_columns(customer_supplier_number: nil)
    xml = InvoiceRenderer.new(@invoice, @issuer).emit_xml(nil)
    assert_no_match %r{supplier-no}, xml
  end

  test "renders a valid PDF with and without supplier number (FOP smoke)" do
    @invoice.update_columns(customer_supplier_number: "ACME-VEND-7")
    pdf = InvoiceRenderer.new(@invoice, @issuer).render
    assert pdf.start_with?("%PDF"), "expected a PDF (got #{pdf[0, 16].inspect})"

    @invoice.update_columns(customer_supplier_number: nil)
    pdf = InvoiceRenderer.new(@invoice, @issuer).render
    assert pdf.start_with?("%PDF"), "expected a PDF (got #{pdf[0, 16].inspect})"
  end

  test "omits country line on both sender and recipient when they share a country" do
    @invoice.update_columns(customer_country_iso2: @issuer.country_iso2)
    xml = InvoiceRenderer.new(@invoice, @issuer).emit_xml(nil)
    assert_no_match %r{<address>[^<]*Netherlands}, xml
    assert_no_match %r{<address>[^<]*Niederlande}, xml
  end

  test "renders country lines in the customer's language" do
    @invoice.customer.update!(language: languages(:german))
    @issuer.update!(country_iso2: "AT")
    @invoice.update_columns(customer_country_iso2: "DE")
    xml = InvoiceRenderer.new(@invoice, @issuer).emit_xml(nil)
    assert_match %r{<issuer>.*<address>[^<]*Österreich}m, xml
    assert_match %r{<recipient>.*<address>[^<]*Deutschland}m, xml
  end

  test "omits country line when one side is the unknown sentinel" do
    @invoice.update_columns(customer_country_iso2: AddressFormatter::UNKNOWN_COUNTRY)
    xml = InvoiceRenderer.new(@invoice, @issuer).emit_xml(nil)
    assert_no_match %r{<recipient>.*Unknown}m, xml
    assert_no_match %r{<recipient>.*Unbekannt}m, xml
  end
end
