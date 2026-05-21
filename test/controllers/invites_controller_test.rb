require 'test_helper'

class InvitesControllerTest < ActionDispatch::IntegrationTest
  test "show pending invite renders" do
    sign_out
    get invite_url(user_invites(:pending).token)
    assert_response :success
  end

  test "show expired invite renders warning" do
    sign_out
    get invite_url(user_invites(:expired).token)
    assert_response :success
    assert_select '.alert-warning', text: /expired/
  end

  test "show consumed invite renders warning" do
    sign_out
    get invite_url(user_invites(:consumed).token)
    assert_response :success
    assert_select '.alert-warning', text: /already been used/
  end

  test "unknown invite token renders 404" do
    sign_out
    get invite_url("does-not-exist")
    assert_response :not_found
  end

  test "happy path: invite consumption creates user and identity" do
    sign_out
    invite = user_invites(:pending)
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new(
      provider: "github",
      uid: "7777",
      info: { nickname: "newbie", name: "New Bie", email: "n@example.com" }
    )

    # Visit the invite page — stashes invite token in session.
    get invite_url(invite.token)
    assert_response :success

    # Hit the OmniAuth callback — should redirect back to invite page with pending_auth.
    get "/auth/github/callback"
    assert_redirected_to invite_path(invite.token)
    follow_redirect!
    assert_response :success
    assert_select 'h4', text: /Choose your username/

    # Submit the accept form.
    assert_difference -> { User.count } => +1,
                     -> { UserIdentity.count } => +1,
                     -> { UserSession.count } => +1 do
      post invite_accept_url(invite.token), params: { username: "newbie", full_name: "New Bie" }
    end

    user = User.find_by(username: "newbie")
    assert user
    assert_equal 1, user.identities.count
    assert_equal "github", user.identities.first.provider
    assert_equal "7777", user.identities.first.uid

    invite.reload
    assert invite.consumed?
    assert_equal user, invite.consumed_by_user

    %w[user_created identity_added invite_consumed login].each do |et|
      assert AuditEvent.where(event_type: et, subject_user: user).exists?, "missing #{et}"
    end
  ensure
    OmniAuth.config.test_mode = false
    OmniAuth.config.mock_auth[:github] = nil
  end

  test "reusing a consumed invite is rejected" do
    sign_out
    invite = user_invites(:consumed)
    get invite_url(invite.token)
    assert_response :success
    assert_select '.alert-warning'
  end

  test "accept fails without pending_auth in session" do
    sign_out
    invite = user_invites(:pending)
    assert_no_difference("User.count") do
      post invite_accept_url(invite.token), params: { username: "x", full_name: "X" }
    end
    assert_redirected_to invite_path(invite.token)
  end
end
