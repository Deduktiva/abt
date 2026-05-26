require "test_helper"

class ActionButtonsHelperTest < ActionView::TestCase
  helper ApplicationHelper

  # Smoke tests that pin the established glyph + Bootstrap color + accessible
  # name for each helper. Update these when CLAUDE.md's "Button Glyphs" table
  # changes — they are the executable copy of the policy.
  #
  # The permission: mechanic is shared via `return nil if permission && !can?(...)`
  # in every helper, so it gets one set of dedicated cases against delete_button
  # rather than being re-tested per verb.

  # --- Tier 3 (glyph-only) ---

  test "delete_button renders glyph-only with title and aria-label" do
    customer = Customer.new
    customer.class.define_singleton_method(:name) { "Customer" }
    html = delete_button(customer)
    assert_glyph_link html, glyph: "🗑", klass: "btn-danger", title: "Delete"
    assert_match(/data-turbo-confirm=/, html)
  end

  test "pdf_button renders glyph-only with title, opens in new tab" do
    html = pdf_button("/foo.pdf")
    assert_glyph_link html, glyph: "📄", klass: "btn-success", title: "PDF"
    assert_match(/target="_blank"/, html)
  end

  test "preview_button renders glyph-only, info color, new tab" do
    html = preview_button("/preview")
    assert_glyph_link html, glyph: "👁", klass: "btn-info", title: "Preview"
    assert_match(/target="_blank"/, html)
  end

  # --- Tier 2 (glyph + text, POST form) ---

  test "publish_button renders glyph + text, warning color, POST form" do
    html = publish_button("/publish")
    assert_post_button html, label: "🚀 Publish", klass: "btn-warning"
    assert_match(%r{<form[^>]*action="/publish"}, html)
  end

  test "unblock_button renders glyph + text, success color" do
    html = unblock_button("/unblock")
    assert_post_button html, label: "✅ Unblock", klass: "btn-success"
  end

  test "reset_passkeys_button is text-only despite Tier 2 form rendering" do
    html = reset_passkeys_button("/reset")
    assert_post_button html, label: "Reset passkeys", klass: "btn-warning"
    refute_match(/🔄/, html)
  end

  test "unpublish_button renders glyph + text, outline-secondary color" do
    html = unpublish_button("/unpublish")
    assert_post_button html, label: "↩️ Unpublish", klass: "btn-outline-secondary"
  end

  # --- Tier 1 (plain link) ---

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

  # --- save_button (form-submit shape) ---

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

  # --- Permission gate (shared across every helper; tested once via delete_button) ---

  test "permission: returns the button when current user has it" do
    Current.user = users(:alice)
    html = delete_button(customers(:good_eu), permission: "customers.edit")
    assert_match(/btn-danger/, html)
    assert_includes html, "🗑"
  ensure
    Current.user = nil
  end

  test "permission: returns nil when current user lacks it" do
    Current.user = users(:bob)
    assert_nil delete_button(customers(:good_eu), permission: "customers.edit")
  ensure
    Current.user = nil
  end

  test "permission: returns nil when there is no current user" do
    Current.user = nil
    assert_nil delete_button(customers(:good_eu), permission: "customers.edit")
  end

  test "permission: gate also covers save_button (button_tag shape)" do
    Current.user = users(:bob)
    assert_nil save_button(permission: "customers.edit")
  ensure
    Current.user = nil
  end

  private

  def assert_glyph_link(html, glyph:, klass:, title:)
    assert_includes html, glyph
    assert_match(/#{Regexp.escape(klass)}/, html)
    assert_match(/title="#{Regexp.escape(title)}"/, html)
    assert_match(/aria-label="#{Regexp.escape(title)}"/, html)
  end

  def assert_post_button(html, label:, klass:)
    assert_includes html, label
    assert_match(/#{Regexp.escape(klass)}/, html)
    assert_match(%r{<form[^>]*method="post"}, html)
  end
end
