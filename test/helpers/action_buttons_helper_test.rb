require "test_helper"

class ActionButtonsHelperTest < ActionView::TestCase
  # Smoke tests that pin the established glyph + Bootstrap color + accessible
  # name for each helper. Update these when CLAUDE.md's "Button Glyphs" table
  # changes — they are the executable copy of the policy.

  test "delete_button renders glyph-only with title and aria-label" do
    customer = Customer.new
    customer.class.define_singleton_method(:name) { "Customer" }
    html = delete_button(customer)
    assert_match(/btn-danger/, html)
    assert_match(/title="Delete"/, html)
    assert_match(/aria-label="Delete"/, html)
    assert_includes html, "🗑"
    assert_match(/data-turbo-confirm=/, html)
  end

  test "pdf_button renders glyph-only with title, opens in new tab" do
    html = pdf_button("/foo.pdf")
    assert_includes html, "📄"
    assert_match(/btn-success/, html)
    assert_match(/title="PDF"/, html)
    assert_match(/aria-label="PDF"/, html)
    assert_match(/target="_blank"/, html)
  end

  test "preview_button renders glyph-only, info color, new tab" do
    html = preview_button("/preview")
    assert_includes html, "👁"
    assert_match(/btn-info/, html)
    assert_match(/title="Preview"/, html)
    assert_match(/target="_blank"/, html)
  end

  test "publish_button renders glyph + text, warning color, POST form" do
    html = publish_button("/publish")
    assert_includes html, "🚀 Publish"
    assert_match(/btn-warning/, html)
    assert_match(%r{<form[^>]*action="/publish"}, html)
    assert_match(%r{method="post"}, html)
  end

  test "convert_to_invoice_button uses the rocket and info color" do
    html = convert_to_invoice_button("/convert", confirm: "Sure?")
    assert_includes html, "🚀 Convert to Invoice"
    assert_match(/btn-info/, html)
    assert_match(/data-turbo-confirm="Sure\?"/, html)
  end

  test "unblock_button renders glyph + text, success color" do
    html = unblock_button("/unblock")
    assert_includes html, "✅ Unblock"
    assert_match(/btn-success/, html)
  end

  test "reset_passkeys_button is text-only despite Tier 2 form rendering" do
    html = reset_passkeys_button("/reset")
    assert_includes html, "Reset passkeys"
    refute_match(/🔄/, html)
    assert_match(/btn-warning/, html)
  end

  test "audit_log_button uses clipboard glyph + text" do
    html = audit_log_button("/audit")
    assert_includes html, "📋 Audit log"
    assert_match(/btn-secondary/, html)
  end

  test "nav_button renders the given label with info color" do
    html = nav_button("Invoices", "/invoices")
    assert_includes html, "Invoices"
    assert_match(/btn-info/, html)
    assert_match(%r{href="/invoices"}, html)
  end
end
