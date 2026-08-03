require "test_helper"

class Account::BlocksControllerTest < ActionDispatch::IntegrationTest
  skip_default_signin!

  test "self-block sets blocked_at and terminates all sessions" do
    sign_in_as(users(:bob))
    other_session, _plain = UserSession.create_for!(user: users(:bob), request: nil)

    post account_block_path
    assert_response :redirect

    assert users(:bob).reload.blocked?
    assert_equal "user self-requested", users(:bob).blocked_reason
    assert other_session.reload.terminated_at.present?
  end

  test "self-block records audit event" do
    sign_in_as(users(:bob))
    assert_difference -> { UserAuditEvent.where(action: "blocked").count }, 1 do
      post account_block_path
    end
  end

  test "the last active admin cannot self-block" do
    groups(:admin).users << users(:blocked_carol)
    sign_in_as(users(:alice))

    post account_block_path
    assert_redirected_to account_profile_path
    assert_not users(:alice).reload.blocked?
  end

  test "unauthenticated user cannot self-block" do
    post account_block_path
    assert_response :redirect
    assert_redirected_to new_session_path
    assert_not users(:alice).reload.blocked?
  end
end
