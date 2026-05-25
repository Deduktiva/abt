require "test_helper"

class InvitesControllerTest < ActionDispatch::IntegrationTest
  skip_default_signin!

  test "show with valid signup token renders form" do
    get invite_path(token: "pending-signup-token")
    assert_response :success
    assert_select "h1", text: /Create your account/i
  end

  test "show with expired token returns 404 with invalid view" do
    get invite_path(token: "expired-signup-token")
    assert_response :not_found
    assert_select "h1", text: /Invite invalid/i
  end

  test "show with used token returns 404" do
    get invite_path(token: "used-signup-token")
    assert_response :not_found
  end

  test "show with unknown token returns 404" do
    get invite_path(token: "totally-bogus")
    assert_response :not_found
  end

  test "options endpoint validates form fields" do
    post options_invite_path(token: "pending-signup-token"),
         params: { username: "", full_name: "", email: "" },
         as: :json
    assert_response :unprocessable_content
    body = JSON.parse(response.body)
    assert body["errors"].any?
  end

  test "options endpoint rejects taken username" do
    post options_invite_path(token: "pending-signup-token"),
         params: { username: "alice", full_name: "X", email: "x@example.com" },
         as: :json
    assert_response :unprocessable_content
    assert_match(/taken/i, JSON.parse(response.body)["error"])
  end

  test "verify endpoint returns 422 (not 500) when credential payload is missing" do
    post options_invite_path(token: "pending-signup-token"),
         params: { username: "newuser", full_name: "New User", email: "newuser@example.com" },
         as: :json
    assert_response :success

    post verify_invite_path(token: "pending-signup-token"), params: {}, as: :json
    assert_response :unprocessable_content
    assert_match(/credential|verification/i, JSON.parse(response.body)["error"])
  end

  test "verify endpoint returns 422 (not 500) when credential payload is a string" do
    post options_invite_path(token: "pending-signup-token"),
         params: { username: "newuser2", full_name: "New User", email: "newuser2@example.com" },
         as: :json
    assert_response :success

    post verify_invite_path(token: "pending-signup-token"),
         params: { credential: "not-a-hash" },
         as: :json
    assert_response :unprocessable_content
  end
end
