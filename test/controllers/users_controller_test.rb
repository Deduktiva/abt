require 'test_helper'

class UsersControllerTest < ActionDispatch::IntegrationTest
  test "index lists users" do
    get users_url
    assert_response :success
    assert_select 'td', text: 'alice'
    assert_select 'td', text: 'bob'
  end

  test "show renders user" do
    get user_url(users(:bob))
    assert_response :success
    assert_select 'h1', text: /User: bob/
  end

  test "block terminates all active sessions and writes audit row" do
    bob = users(:bob)
    # Give bob a session so we can verify termination
    UserSession.create!(user: bob, token_digest: UserSession.digest("bob-s1"), last_seen_at: Time.current)
    assert_equal 1, bob.sessions.active.count

    assert_difference("AuditEvent.where(event_type: 'block').count", +1) do
      post block_user_url(bob), params: { reason: "test reason" }
    end
    bob.reload
    assert bob.blocked?
    assert_equal "test reason", bob.blocked_reason
    assert_equal 0, bob.sessions.active.count
  end

  test "cannot block self via management UI" do
    alice = users(:alice)
    post block_user_url(alice)
    assert_redirected_to user_path(alice)
    alice.reload
    refute alice.blocked?
  end

  test "unblock clears blocked_at and writes audit row" do
    charlie = users(:blocked_charlie)
    assert charlie.blocked?
    assert_difference("AuditEvent.where(event_type: 'unblock').count", +1) do
      post unblock_user_url(charlie)
    end
    charlie.reload
    refute charlie.blocked?
  end
end
