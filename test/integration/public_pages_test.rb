require "test_helper"

class PublicPagesTest < ActionDispatch::IntegrationTest
  setup { host! Settings.customer_portal.host }

  test "root shows a branded info page, 200" do
    get public_root_url(host: Settings.customer_portal.host)
    assert_response :success
    assert_select "h1", text: /document portal/i
  end

  test "unknown path shows branded not-found, 404" do
    get "/whatever", headers: { "HOST" => Settings.customer_portal.host }
    assert_response :not_found
    assert_select "h1"
  end

  test "root localizes from Accept-Language" do
    get public_root_url(host: Settings.customer_portal.host),
        headers: { "Accept-Language" => "de" }
    assert_select "p", text: /Bitte verwenden Sie/
  end
end
