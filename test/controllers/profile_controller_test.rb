require 'test_helper'

class ProfileControllerTest < ActionDispatch::IntegrationTest
  test "show renders profile of current user" do
    get profile_url
    assert_response :success
    assert_select 'dd', text: 'alice'
  end

  test "self-block blocks user, terminates sessions, redirects to login" do
    alice = users(:alice)
    UserSession.create!(user: alice, token_digest: UserSession.digest("alice-extra"), last_seen_at: Time.current)
    assert alice.sessions.active.count >= 1

    assert_difference("AuditEvent.where(event_type: 'self_block', subject_user: alice).count", +1) do
      post profile_block_url
    end
    alice.reload
    assert alice.blocked?
    assert_equal "user self-requested", alice.blocked_reason
    assert_equal 0, alice.sessions.active.count
    assert_redirected_to login_path
  end

  test "sessions index lists active sessions for current user" do
    get profile_sessions_url
    assert_response :success
    # Alice has two fixture sessions plus one created by sign_in_as in setup.
    assert_select 'table tbody tr', minimum: 1
  end

  test "terminate other session keeps user logged in" do
    other = user_sessions(:alice_browser_one)
    delete profile_session_url(other)
    other.reload
    assert other.terminated?
    assert_redirected_to profile_sessions_path
  end

  test "terminate current session logs out" do
    # The auto-sign-in helper created a session via the real OAuth callback;
    # it is alice's most-recently-created active session.
    current = users(:alice).sessions.active.order(:created_at).last
    delete profile_session_url(current)
    current.reload
    assert current.terminated?
    assert_redirected_to login_path
  end
end
