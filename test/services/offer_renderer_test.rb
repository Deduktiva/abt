require "test_helper"

class OfferRendererTest < ActiveSupport::TestCase
  setup { @issuer = IssuerCompany.get_the_issuer! }

  test "frozen version emits snapshot recipient, number, and valid-until" do
    version = offer_versions(:sent_offer_v1)
    xml = OfferRenderer.new(version, @issuer).emit_xml(nil)
    assert_match "Snapshot Name", xml
    assert_match "<number>20260601-01</number>", xml
    assert_match "<valid-until>", xml
    assert_no_match(/<version-number>/, xml) # version row only from v2 onward
  end

  test "second and later versions emit a version-number element" do
    v1 = offer_versions(:sent_offer_v1)
    v2 = v1.offer.versions.find_by(version_number: 2)
    v2.update!(sent_at: Time.current, date: Date.current,
               customer_name: "Snap", customer_address: "A", customer_country_iso2: "DE",
               payment_terms_days: 30)
    xml = OfferRenderer.new(v2, @issuer).emit_xml(nil)
    assert_match "<version-number>2</version-number>", xml
  end

  test "draft version renders live customer data with a DRAFT number" do
    version = offer_versions(:draft_offer_v1)
    xml = OfferRenderer.new(version, @issuer).emit_xml(nil)
    assert_match version.offer.customer.name, xml
    assert_match "<number>DRAFT</number>", xml
  end

  test "no VAT ids and no totals appear in the XML" do
    xml = OfferRenderer.new(offer_versions(:sent_offer_v1), @issuer).emit_xml(nil)
    assert_no_match(/vat-id/, xml)
    assert_no_match(/<sums>/, xml)
  end

  test "milestones carry trigger and formatted amount data" do
    xml = OfferRenderer.new(offer_versions(:sent_offer_v1), @issuer).emit_xml(nil)
    assert_match "<trigger>on_order</trigger>", xml
    assert_match "Setup", xml
  end

  test "draft valid-until is computed from today plus validity days" do
    version = offer_versions(:draft_offer_v1)
    xml = OfferRenderer.new(version, @issuer).emit_xml(nil)
    expected = (Date.current + version.offer.validity_days).iso8601
    assert_match "<valid-until>#{expected}</valid-until>", xml
  end

  test "prelude and boilerplate are embedded as FO fragments" do
    version = offer_versions(:sent_offer_v1)
    version.update!(prelude: "<p>Dear customer</p>", boilerplate: "<h1>Terms</h1>")
    xml = OfferRenderer.new(version.reload, @issuer).emit_xml(nil)
    assert_match "Dear customer", xml
    assert_match "Terms", xml
    assert_includes xml, %(xmlns:fo="http://www.w3.org/1999/XSL/Format")
  end

  test "FOP smoke: renders a real PDF" do
    version = offer_versions(:sent_offer_v1)
    pdf = OfferRenderer.new(version, @issuer).render
    assert pdf.start_with?("%PDF"), "expected a PDF, got: #{pdf[0, 20].inspect}"
  end
end
