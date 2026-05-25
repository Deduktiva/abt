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
end
