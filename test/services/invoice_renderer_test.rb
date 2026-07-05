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

  test "forwards the issuer's money_decimal_places into the PDF (FOP smoke)" do
    @issuer.update!(money_decimal_places: 0)
    renderer = InvoiceRenderer.new(@invoice, @issuer)
    assert_match %r{<money-decimal-places>0</money-decimal-places>}, renderer.emit_xml(nil)
    assert renderer.render.start_with?("%PDF"), "expected a PDF"
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

  test "prelude is emitted as FO blocks inside the prelude element" do
    @invoice.prelude = "<div>Hello <strong>world</strong></div>"
    @invoice.save!
    xml = InvoiceRenderer.new(@invoice, @issuer).emit_xml(nil)
    assert_includes xml, "<prelude>"
    assert_includes xml, %(<fo:inline font-weight="bold">world</fo:inline>)
    assert_includes xml, %(xmlns:fo="http://www.w3.org/1999/XSL/Format")
  end

  test "renders a PDF with rich-text prelude formatting (FOP smoke)" do
    @invoice.prelude = "<h1>Title</h1><div>Hello <strong>bold</strong> and <em>italic</em></div><ul><li>one</li><li>two</li></ul><ol><li>a</li><li>b<ol><li>nested</li></ol></li></ol>"
    @invoice.save!
    pdf = InvoiceRenderer.new(@invoice, @issuer).render
    assert pdf.start_with?("%PDF"), "expected a PDF (got #{pdf[0, 16].inspect})"
  end
end
