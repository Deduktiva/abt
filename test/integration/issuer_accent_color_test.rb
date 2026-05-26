require "test_helper"

class IssuerAccentColorTest < ActionDispatch::IntegrationTest
  test "layout head injects --issuer-accent-color on a non-dashboard page" do
    get users_url
    assert_response :success
    assert_match(
      %r{<style\b[^>]*\bnonce=['"][^'"]+['"][^>]*>\s*:root\s*\{\s*--issuer-accent-color:\s*\#3366cc;\s*\}\s*</style>},
      @response.body,
      "expected the layout to render a nonce'd style tag setting --issuer-accent-color"
    )
  end

  test "layout omits the style tag when no accent color is configured" do
    issuer_companies(:one).update!(document_accent_color: nil)
    get users_url
    assert_response :success
    assert_no_match(/--issuer-accent-color/, @response.body)
  end
end
