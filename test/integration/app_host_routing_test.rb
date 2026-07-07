require "test_helper"

# The authenticated app surface (login, invites, WebAuthn, CRUD) is host
# constrained to the app host. On the customer portal host these routes do not
# exist: GET paths fall through to the portal not-found catch-all, and other
# verbs miss routing entirely. Both surface as a 404.
class AppHostRoutingTest < ActionDispatch::IntegrationTest
  test "login page resolves on the app host" do
    host! Settings.app.host
    get "/session/new"
    assert_response :success
  end

  test "login page resolves on the default test host" do
    host! "www.example.com"
    get "/session/new"
    assert_response :success
  end

  test "login page is unreachable on the customer portal host" do
    host! Settings.customer_portal.host
    get "/session/new"
    assert_response :not_found
    assert_select "h1"
  end

  test "invites are unreachable on the customer portal host" do
    host! Settings.customer_portal.host
    get "/invites?token=whatever"
    assert_response :not_found
    assert_select "h1"
  end

  test "POST session options is unreachable on the customer portal host" do
    host! Settings.customer_portal.host
    post "/session/options"
    assert_response :not_found
  end

  test "portal root still resolves on the customer portal host" do
    host! Settings.customer_portal.host
    get "/"
    assert_response :success
    assert_select "h1", text: /document portal/i
  end
end
