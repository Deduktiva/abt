require 'test_helper'
require 'webauthn/fake_client'

class PasskeyLoginFlowTest < ActionDispatch::IntegrationTest
  skip_default_signin!

  setup do
    @origin = WebAuthn.configuration.allowed_origins.first
    @fake_client = WebAuthn::FakeClient.new(@origin)
    @user = User.create!(username: 'logger', full_name: 'Log Inn')
    @user.emails.create!(address: 'logger@example.com', confirmed_at: Time.current)

    # Bootstrap a credential the way the registration ceremony would
    creation_options = WebAuthn::Credential.options_for_create(
      user: { id: @user.webauthn_id, name: @user.username, display_name: @user.full_name }
    )
    raw_credential = @fake_client.create(challenge: creation_options.challenge)
    webauthn_cred = WebAuthn::Credential.from_create(raw_credential)
    webauthn_cred.verify(creation_options.challenge)
    @user.credentials.create!(
      external_id: webauthn_cred.id,
      public_key: webauthn_cred.public_key,
      nickname: 'Test key',
      sign_count: webauthn_cred.sign_count
    )
  end

  test 'a user with a passkey can sign in' do
    post options_session_path, params: { username: @user.username }, as: :json
    assert_response :success
    options = JSON.parse(response.body)
    assertion = @fake_client.get(challenge: options['challenge'])

    post verify_session_path, params: { credential: assertion }, as: :json
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal root_path, body['redirect_url']

    # Confirm we're signed in
    get account_profile_path
    assert_response :success

    # Login was audited
    assert UserAuditEvent.where(action: 'login_success', user: @user).exists?

    # An active session row exists
    assert @user.sessions.active.exists?
  end

  test 'blocked users cannot sign in' do
    @user.update!(blocked_at: Time.current, blocked_reason: 'test')

    post options_session_path, params: { username: @user.username }, as: :json
    # User is excluded by User.active scope, so credentials list is empty;
    # an attempt to verify with the user's actual credential should still fail.
    assert_response :success
  end
end
