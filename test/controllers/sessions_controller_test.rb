require 'test_helper'

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "signed-out request to login is allowed" do
    sign_out
    get login_url
    assert_response :success
    assert_select 'form'
  end

  test "signed-out access to protected resources redirects to login" do
    sign_out
    [customers_url, invoices_url, users_url, audit_events_url, profile_url, user_invites_url].each do |url|
      get url
      assert_redirected_to login_path, "#{url} should redirect to /login when signed out"
    end
  end

  test "omniauth callback signs in existing identity" do
    sign_out
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new(
      provider: "github",
      uid: "1001",
      info: { nickname: "alice", name: "Alice Example", email: "alice@example.com" }
    )

    assert_difference("AuditEvent.where(event_type: 'login').count", +1) do
      assert_difference("UserSession.count", +1) do
        get "/auth/github/callback"
        follow_redirect!
      end
    end
    assert_response :success
  ensure
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:github] = nil
  end

  test "blocked user cannot complete oauth login" do
    sign_out
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new(
      provider: "github",
      uid: "1003",
      info: { nickname: "charlie" }
    )

    assert_no_difference("UserSession.count") do
      get "/auth/github/callback"
    end
    assert_redirected_to login_path
    follow_redirect!
    assert_select '.alert-danger', text: /blocked/
  ensure
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:github] = nil
  end

  test "callback with no identity and no invite is rejected" do
    sign_out
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new(
      provider: "github",
      uid: "9999",
      info: { nickname: "stranger" }
    )

    assert_difference("AuditEvent.where(event_type: 'login_failed').count", +1) do
      get "/auth/github/callback"
    end
    assert_redirected_to login_path
  ensure
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:github] = nil
  end

  test "logout terminates session and writes audit row" do
    sign_in_as(users(:alice))
    assert_difference("AuditEvent.where(event_type: 'logout').count", +1) do
      delete logout_url
    end
    assert_redirected_to login_path
  end
end
