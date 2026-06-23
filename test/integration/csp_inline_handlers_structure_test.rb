require "test_helper"

# Structural checks that the inline-JS-replacement Stimulus wiring is rendered
# on the affected pages. Complements the system tests, but does not require a
# browser so it can run in CI environments without Chrome.
class CspInlineHandlersStructureTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:alice))
  end

  test "users/show wires the email-replace toggle via Stimulus, with no inline handler" do
    get user_path(users(:alice))
    assert_response :success
    body = @response.body

    assert_no_match(/onclick=/, body, "inline onclick must be replaced by Stimulus")
    assert_match(/data-controller=['"][^'"]*toggle-visibility/, body)
    assert_match(/data-action=['"][^'"]*toggle-visibility#toggle/, body)
    assert_match(/data-toggle-visibility-target=['"]panel['"]/, body)
  end

  test "delivery_notes form wires clear-date button via Stimulus" do
    get edit_delivery_note_path(delivery_notes(:draft_delivery_note))
    assert_response :success
    body = @response.body

    assert_no_match(/onclick=/, body, "inline onclick must be replaced by Stimulus")
    clear_input_controllers = body.scan(/data-controller=['"][^'"]*clear-input/)
    assert clear_input_controllers.length >= 1,
      "expected a clear-input controller, got #{clear_input_controllers.length}"
    assert_match(/data-action=['"][^'"]*clear-input#clear/, body)
    assert_match(/data-clear-input-target=['"]field['"]/, body)
  end

  test "layout theme script carries a CSP nonce" do
    get root_path
    body = @response.body
    expected_nonce = csp_nonce(@response)

    assert_match(/<script[^>]*\bnonce=['"]#{Regexp.escape(expected_nonce)}['"][^>]*>[\s\S]*?prefers-color-scheme/, body,
      "theme detection inline script must carry the same nonce as the CSP header (got something else, e.g. 'true')")
  end

  test "Content-Security-Policy header is present and strict" do
    get root_path
    csp = @response.headers["Content-Security-Policy"]

    assert csp.present?, "CSP header should be set"
    assert_no_match(/unsafe-inline/, csp, "CSP must not allow unsafe-inline")
    assert_no_match(/unsafe-eval/, csp, "CSP must not allow unsafe-eval")
    assert_match(/script-src[^;]*'nonce-[^']+'/, csp, "script-src must include a nonce")
    assert_match(/style-src[^;]*'nonce-[^']+'/, csp, "style-src must include a nonce")
    assert_match(/object-src 'none'/, csp)
    assert_match(/frame-ancestors 'none'/, csp)
  end

  test "Permissions-Policy header is present and disables sensors" do
    get root_path
    pp = @response.headers["Permissions-Policy"]

    # Debug what headers were actually returned if missing
    unless pp.present?
      headers_summary = @response.headers.to_h.keys.sort.join(", ")
      flunk "Permissions-Policy header missing. Headers present: #{headers_summary}"
    end

    assert_match(/camera=\(\)/, pp)
    assert_match(/microphone=\(\)/, pp)
    assert_match(/geolocation=\(\)/, pp)
    assert_match(/payment=\(\)/, pp)
  end

  test "issuer_companies/show carries no inline style attribute and emits nonced accent-color block" do
    get issuer_company_path
    body = @response.body
    expected_nonce = csp_nonce(@response)

    assert_no_match(/\bstyle=['"]/, body, "no inline style attributes allowed on issuer companies show")
    assert_match(/<style[^>]*\bnonce=['"]#{Regexp.escape(expected_nonce)}['"][^>]*>[\s\S]*?--issuer-accent-color/, body,
      "accent-color <style> block must carry the same nonce as the CSP header (`nonce: true` literal is a known regression)")
  end

  test "home dashboard carries no inline style attribute" do
    get root_path
    body = @response.body
    expected_nonce = csp_nonce(@response)

    assert_no_match(/\bstyle=['"]/, body, "no inline style attributes allowed on the dashboard")
    assert_match(/<style[^>]*\bnonce=['"]#{Regexp.escape(expected_nonce)}['"][^>]*>[\s\S]*?--issuer-accent-color/, body,
      "accent-color <style> block must carry the same nonce as the CSP header")
  end

  test "invoices show carries no inline style attribute" do
    get invoice_path(invoices(:published_invoice))
    body = @response.body

    assert_no_match(/\bstyle=['"]/, body, "no inline style attributes allowed on invoices show")
  end

  test "delivery notes show carries no inline style attribute" do
    get delivery_note_path(delivery_notes(:published_delivery_note))
    body = @response.body

    assert_no_match(/\bstyle=['"]/, body, "no inline style attributes allowed on delivery notes show")
  end

  test "users show carries no inline style attribute" do
    get user_path(users(:alice))
    body = @response.body

    assert_no_match(/\bstyle=['"]/, body, "no inline style attributes allowed on users show")
  end

  test "customer_contacts new form carries no inline style attribute" do
    get new_customer_customer_contact_path(customers(:good_eu))
    assert_response :success
    body = @response.body

    assert_no_match(/\bstyle=['"]/, body, "no inline style attributes allowed on the new customer-contact form")
  end

  test "customer_contacts edit form carries no inline style attribute" do
    get edit_customer_contact_path(customer_contacts(:good_eu_accounting))
    assert_response :success
    body = @response.body

    assert_no_match(/\bstyle=['"]/, body, "no inline style attributes allowed on the edit customer-contact form")
  end

  test "customer portal page carries no inline style attribute" do
    issuer_companies(:one).update!(png_logo: "fakepng")
    get public_root_url(host: Settings.customer_portal.host)
    assert_response :success
    body = @response.body

    assert_no_match(/\bstyle=['"]/, body, "no inline style attributes allowed on the customer portal")
  end

  private

  def csp_nonce(response)
    csp = response.headers["Content-Security-Policy"].to_s
    match = csp.match(/'nonce-([^']+)'/)
    flunk "CSP header has no nonce: #{csp.inspect}" unless match
    match[1]
  end
end
