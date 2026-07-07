require "test_helper"
require "webauthn/fake_client"

class PasskeySignupFlowTest < ActionDispatch::IntegrationTest
  skip_default_signin!

  test "a user can sign up via an invite, register a passkey, then sign in" do
    _invite, plaintext = UserInvite.create_signup!(actor: nil)
    origin = WebAuthn.configuration.allowed_origins.first
    fake_client = WebAuthn::FakeClient.new(origin)

    # Step 1: GET the invite landing page (anonymous)
    get invite_path(token: plaintext)
    assert_response :success

    # Step 2: POST signup form fields → receive WebAuthn creation options
    post options_invite_path(token: plaintext),
         params: { username: "newbie", full_name: "New B. User", email: "newbie@example.com", nickname: "Test key" },
         as: :json
    assert_response :success
    options = JSON.parse(response.body)
    challenge = options["challenge"]

    # Step 3: Have the fake authenticator produce an attestation for that challenge
    public_key_credential = fake_client.create(challenge: challenge)

    # Step 4: POST the credential to verify
    assert_difference -> { User.count } => 1,
                      -> { UserEmail.count } => 1,
                      -> { UserCredential.count } => 1 do
      post verify_invite_path(token: plaintext),
           params: { credential: public_key_credential },
           as: :json
    end
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal account_profile_path, body["redirect_url"]

    # Should now be signed in: visit /account/profile and see the user
    new_user = User.find_by(username: "newbie")
    assert_not_nil new_user
    assert_equal "New B. User", new_user.full_name
    assert new_user.confirmed_emails.exists?(address: "newbie@example.com")
    assert_equal 1, new_user.credentials.count

    # Audit events are recorded
    assert UserAuditEvent.where(action: "signup_completed", user: new_user).exists?
    assert UserAuditEvent.where(action: "passkey_added", user: new_user).exists?

    # Invite is consumed
    invite_record = UserInvite.find_by(used_by_user: new_user)
    assert_not_nil invite_record
    assert invite_record.used_at.present?
  end

  test "a second verify with the same invite token yields 422, not a second account" do
    _invite, plaintext = UserInvite.create_signup!(actor: nil)
    origin = WebAuthn.configuration.allowed_origins.first

    first = open_session
    second = open_session

    first_credential = signup_credential(first, plaintext, origin, username: "racewinner", email: "racewinner@example.com")
    second_credential = signup_credential(second, plaintext, origin, username: "raceloser", email: "raceloser@example.com")

    assert_difference -> { User.count } => 1 do
      first.post verify_invite_path(token: plaintext), params: { credential: first_credential }, as: :json
    end
    assert_equal 200, first.response.status

    assert_no_difference -> { User.count } do
      second.post verify_invite_path(token: plaintext), params: { credential: second_credential }, as: :json
    end
    assert_equal 422, second.response.status
    assert_match(/invalid or expired/i, JSON.parse(second.response.body)["error"])

    assert User.exists?(username: "racewinner")
    assert_not User.exists?(username: "raceloser")
  end

  test "invalid invite token redirects to invalid view" do
    get invite_path(token: "not-a-real-token")
    assert_response :not_found
  end

  test "options endpoint rejects taken username" do
    _invite, plaintext = UserInvite.create_signup!(actor: nil)
    post options_invite_path(token: plaintext),
         params: { username: "alice", full_name: "X", email: "fresh@example.com" },
         as: :json
    assert_response :unprocessable_content
    assert_match(/taken/i, JSON.parse(response.body)["error"])
  end

  private

  def signup_credential(session, plaintext, origin, username:, email:)
    session.post options_invite_path(token: plaintext),
                 params: { username: username, full_name: "Race #{username}", email: email },
                 as: :json
    assert_equal 200, session.response.status
    challenge = JSON.parse(session.response.body)["challenge"]
    WebAuthn::FakeClient.new(origin).create(challenge: challenge)
  end
end
