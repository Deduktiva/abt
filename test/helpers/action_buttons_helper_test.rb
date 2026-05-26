require "test_helper"

class ActionButtonsHelperTest < ActionView::TestCase
  helper ApplicationHelper

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

  test "delete_button with permission: returns the link when user has it" do
    Current.user = users(:alice)
    customer = customers(:good_eu)
    html = delete_button(customer, permission: "customers.edit")
    assert_match(/btn-danger/, html)
    assert_includes html, "🗑"
  ensure
    Current.user = nil
  end

  test "delete_button with permission: returns nil when user lacks it" do
    Current.user = users(:bob)
    customer = customers(:good_eu)
    assert_nil delete_button(customer, permission: "customers.edit")
  ensure
    Current.user = nil
  end

  test "delete_button with permission: returns nil when no current user" do
    Current.user = nil
    customer = customers(:good_eu)
    assert_nil delete_button(customer, permission: "customers.edit")
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

  test "nav_button renders the given label with outline-secondary style" do
    html = nav_button("Invoices", "/invoices")
    assert_includes html, "Invoices"
    assert_match(/btn-outline-secondary/, html)
    assert_match(%r{href="/invoices"}, html)
  end

  test "save_button renders a submit button bound to the shared form id" do
    html = save_button
    assert_match(/<button[^>]*type="submit"/, html)
    assert_match(/form="page-form"/, html)
    assert_match(/btn-primary/, html)
    assert_includes html, "Save"
  end

  test "save_button respects custom label" do
    html = save_button(label: "Update Issuer Company")
    assert_includes html, "Update Issuer Company"
  end

  test "save_button with permission: returns nil when user lacks it" do
    Current.user = users(:bob)
    assert_nil save_button(permission: "customers.edit")
  ensure
    Current.user = nil
  end
end
