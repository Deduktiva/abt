require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  skip_default_signin!

  test "index requires authentication" do
    get users_path
    assert_redirected_to new_session_path
  end

  test "index lists users when signed in" do
    sign_in_as(users(:alice))
    get users_path
    assert_response :success
    assert_select "td", text: "alice"
    assert_select "td", text: "bob"
  end

  test "show renders user details" do
    sign_in_as(users(:alice))
    get user_path(users(:bob))
    assert_response :success
  end

  test "block requires reason" do
    sign_in_as(users(:alice))
    post block_user_path(users(:bob))
    assert_redirected_to user_path(users(:bob))
    assert_not users(:bob).reload.blocked?
  end

  test "block sets reason and terminates sessions" do
    sign_in_as(users(:alice))
    UserSession.create_for!(user: users(:bob), request: nil)

    post block_user_path(users(:bob)), params: { reason: "misuse" }
    assert_redirected_to user_path(users(:bob))
    bob = users(:bob).reload
    assert bob.blocked?
    assert_equal "misuse", bob.blocked_reason
    assert_equal 0, bob.sessions.active.count
  end

  test "block refuses self-target" do
    sign_in_as(users(:alice))
    post block_user_path(users(:alice)), params: { reason: "try" }
    assert_redirected_to user_path(users(:alice))
    assert_not users(:alice).reload.blocked?
  end

  test "unblock clears blocked fields" do
    sign_in_as(users(:alice))
    post unblock_user_path(users(:blocked_carol))
    assert_redirected_to user_path(users(:blocked_carol))
    assert_not users(:blocked_carol).reload.blocked?
  end

  test "unblock refuses unblocked user" do
    sign_in_as(users(:alice))
    post unblock_user_path(users(:bob))
    assert_redirected_to user_path(users(:bob))
  end

  test "reset_passkeys requires user to be blocked" do
    sign_in_as(users(:alice))
    post reset_passkeys_user_path(users(:bob))
    assert_redirected_to user_path(users(:bob))
    assert users(:bob).reload.credentials.exists?
  end

  test "reset_passkeys destroys credentials and creates invite" do
    sign_in_as(users(:alice))
    carol = users(:blocked_carol)
    carol.credentials.create!(external_id: "cx", public_key: "pk", nickname: "k")

    assert_difference -> { UserInvite.where(purpose: UserInvite::PURPOSE_PASSKEY_RESET, target_user: carol).count }, 1 do
      post reset_passkeys_user_path(carol)
    end
    assert_empty carol.reload.credentials
  end

  test "audit returns events for the user" do
    sign_in_as(users(:alice))
    UserAuditEvent.record!(action: "login_success", user: users(:bob), actor: users(:bob))
    get audit_user_path(users(:bob))
    assert_response :success
    assert_select "code", text: "login_success"
  end
end
