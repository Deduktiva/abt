require 'test_helper'

class Profile::PasskeysControllerTest < ActionDispatch::IntegrationTest
  setup do
    @origin = WebAuthn.configuration.allowed_origins.first
    @fake_client = WebAuthn::FakeClient.new(@origin)
  end

  test "index renders" do
    get profile_passkeys_url
    assert_response :success
    assert_select 'h1', text: /My passkeys/
  end

  test "registration_options returns a challenge and stashes it in session" do
    post registration_options_profile_passkeys_url, as: :json
    assert_response :success
    body = JSON.parse(response.body)
    assert body["challenge"].present?
  end

  test "happy path: register a passkey end-to-end" do
    # Step 1: fetch options. The session cookie now holds the challenge.
    post registration_options_profile_passkeys_url, as: :json
    assert_response :success
    options = JSON.parse(response.body)

    # FakeClient drives the navigator.credentials.create-equivalent.
    attestation = @fake_client.create(challenge: options["challenge"], user_verified: true)

    assert_difference "WebauthnCredential.count", +1 do
      assert_difference "AuditEvent.where(event_type: 'passkey_added').count", +1 do
        post profile_passkeys_url, params: { credential: attestation, nickname: "Work laptop" }, as: :json
      end
    end
    assert_response :success
    cred = WebauthnCredential.order(:created_at).last
    assert_equal "Work laptop", cred.nickname
    assert_equal users(:alice), cred.user
  end

  test "create rejects without a stashed challenge" do
    attestation = @fake_client.create(challenge: WebAuthn.configuration.encoder.encode(SecureRandom.random_bytes(32)), user_verified: true)
    post profile_passkeys_url, params: { credential: attestation, nickname: "X" }, as: :json
    assert_response :unprocessable_content
  end

  test "destroy removes a credential and audits it" do
    # Give alice a second sign-in method so removal is allowed.
    users(:alice).webauthn_credentials.create!(
      external_id: "second-fake-id",
      public_key:  "second-fake-key",
      sign_count:  0,
      nickname:    "Second",
      last_used_at: Time.current
    )
    cred = users(:alice).webauthn_credentials.first

    assert_difference "WebauthnCredential.count", -1 do
      assert_difference "AuditEvent.where(event_type: 'passkey_removed').count", +1 do
        delete profile_passkey_url(cred)
      end
    end
    assert_redirected_to profile_passkeys_path
  end

  test "destroy refuses to remove the last sign-in method" do
    # Strip alice down to exactly one credential and no identities.
    users(:alice).identities.destroy_all
    users(:alice).webauthn_credentials.destroy_all
    cred = users(:alice).webauthn_credentials.create!(
      external_id: "only-fake-id",
      public_key:  "only-fake-key",
      sign_count:  0,
      nickname:    "Only",
      last_used_at: Time.current
    )

    # alice has zero identities + 1 passkey, but auto-sign-in re-creates her
    # github identity in test_helper, so make sure that's gone too.
    users(:alice).identities.destroy_all
    assert_equal 1, users(:alice).sign_in_methods_count

    assert_no_difference "WebauthnCredential.count" do
      delete profile_passkey_url(cred)
    end
    assert_redirected_to profile_passkeys_path
    follow_redirect!
    assert_select '.alert-danger', text: /Cannot remove your last sign-in method/
  end
end
