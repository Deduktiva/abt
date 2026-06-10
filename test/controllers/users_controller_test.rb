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

  test "show hides admin action affordances for users without the matching permissions" do
    viewer = Group.create!(name: "Viewer")
    viewer.permissions = %w[users.view]
    bob = users(:bob)
    bob.groups.clear
    bob.groups << viewer
    sign_in_as(bob)

    get user_path(users(:blocked_carol))
    assert_response :success
    # No Reset passkeys / Unblock buttons.
    assert_select "form[action=?]", reset_passkeys_user_path(users(:blocked_carol)), count: 0
    assert_select "form[action=?]", unblock_user_path(users(:blocked_carol)), count: 0
    # No email management UI.
    assert_select "form[action=?]", user_emails_path(users(:blocked_carol)), count: 0
    # No Block form on a non-blocked user.
    get user_path(users(:alice))
    assert_response :success
    assert_select "form[action=?]", block_user_path(users(:alice)), count: 0
  end

  test "show exposes admin action affordances when the user has the matching permissions" do
    sign_in_as(users(:alice))

    get user_path(users(:blocked_carol))
    assert_response :success
    assert_select "form[action=?]", reset_passkeys_user_path(users(:blocked_carol))
    assert_select "form[action=?]", unblock_user_path(users(:blocked_carol))
    assert_select "form[action=?]", user_emails_path(users(:blocked_carol))

    get user_path(users(:bob))
    assert_response :success
    assert_select "form[action=?]", block_user_path(users(:bob))
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

  test "reset_passkeys only emails confirmed addresses" do
    sign_in_as(users(:alice))
    carol = users(:blocked_carol)
    carol.emails.create!(address: "attacker@example.com", confirmed_at: nil)

    perform_enqueued_jobs do
      post reset_passkeys_user_path(carol)
    end

    recipients = ActionMailer::Base.deliveries.flat_map(&:to)
    assert_includes recipients, "carol@example.com"
    refute_includes recipients, "attacker@example.com"
  end

  test "audit returns events for the user" do
    sign_in_as(users(:alice))
    UserAuditEvent.record!(action: "login_success", user: users(:bob), actor: users(:bob))
    get audit_user_path(users(:bob))
    assert_response :success
    assert_select "code", text: "login_success"
  end

  # The takeover chain is: add attacker email -> block target -> reset passkeys.
  # Each of those three primitives must require a different, increasingly
  # restricted permission. A bearer of only users.block must not be able to
  # issue passkey-reset invites or add emails.
  test "users.block alone cannot reset passkeys or manage emails" do
    helpdesk = Group.create!(name: "Helpdesk")
    helpdesk.permissions = %w[users.view users.block]
    bob = users(:bob)
    bob.groups << helpdesk
    sign_in_as(bob)

    carol = users(:blocked_carol)
    # Has users.block, can unblock.
    post unblock_user_path(carol)
    assert_redirected_to user_path(carol)

    # Lacks users.reset_passkeys.
    carol.update!(blocked_at: Time.current, blocked_reason: "test")
    post reset_passkeys_user_path(carol)
    assert_redirected_to root_path

    # Lacks users.auto_confirm_email.
    post user_emails_path(carol), params: { user_email: { address: "evil@example.com" } }
    assert_redirected_to root_path
  end
end
