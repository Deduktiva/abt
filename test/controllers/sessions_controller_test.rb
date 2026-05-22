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

  test "passkey login: happy path signs the user in" do
    sign_out
    # First, register a passkey through the controller so the public key
    # stored matches what FakeClient signs against.
    sign_in_as(users(:alice))
    post registration_options_profile_passkeys_url, as: :json
    options = JSON.parse(response.body)
    fake_client = WebAuthn::FakeClient.new(WebAuthn.configuration.allowed_origins.first)
    attestation = fake_client.create(challenge: options["challenge"], user_verified: true)
    post profile_passkeys_url, params: { credential: attestation, nickname: "Test" }, as: :json
    assert_response :success
    sign_out

    # Now sign in with the passkey.
    post passkey_login_options_url, as: :json
    assert_response :success
    login_opts = JSON.parse(response.body)
    assertion = fake_client.get(challenge: login_opts["challenge"], user_verified: true)

    assert_difference "UserSession.count", +1 do
      assert_difference "AuditEvent.where(event_type: 'login').count", +1 do
        post passkey_login_url, params: { credential: assertion }, as: :json
      end
    end
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal root_path, body["redirect_to"]
    last_login = AuditEvent.where(event_type: "login").order(:created_at).last
    assert_equal "passkey", last_login.metadata["method"]
  end

  test "passkey login: blocked user is rejected" do
    sign_in_as(users(:alice))
    post registration_options_profile_passkeys_url, as: :json
    options = JSON.parse(response.body)
    fake_client = WebAuthn::FakeClient.new(WebAuthn.configuration.allowed_origins.first)
    attestation = fake_client.create(challenge: options["challenge"], user_verified: true)
    post profile_passkeys_url, params: { credential: attestation }, as: :json
    sign_out

    users(:alice).update!(blocked_at: Time.current, blocked_reason: "test")

    post passkey_login_options_url, as: :json
    login_opts = JSON.parse(response.body)
    assertion = fake_client.get(challenge: login_opts["challenge"], user_verified: true)

    assert_no_difference "UserSession.count" do
      post passkey_login_url, params: { credential: assertion }, as: :json
    end
    assert_response :unauthorized
  end

  test "passkey login: unknown credential rejected" do
    sign_out
    # Have FakeClient mint a credential locally without registering it server-side.
    fake_client = WebAuthn::FakeClient.new(WebAuthn.configuration.allowed_origins.first)
    fake_client.create(challenge: WebAuthn.configuration.encoder.encode(SecureRandom.random_bytes(32)), user_verified: true)

    post passkey_login_options_url, as: :json
    options = JSON.parse(response.body)
    assertion = fake_client.get(challenge: options["challenge"], user_verified: true)

    post passkey_login_url, params: { credential: assertion }, as: :json
    assert_response :unauthorized
  end

  test "logout terminates session and writes audit row" do
    sign_in_as(users(:alice))
    assert_difference("AuditEvent.where(event_type: 'logout').count", +1) do
      delete logout_url
    end
    assert_redirected_to login_path
  end
end
