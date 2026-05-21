require "application_system_test_case"

class InviteSignupTest < ApplicationSystemTestCase
  test "end-to-end invite signup via github oauth" do
    invite = UserInvite.create!(created_by_user: users(:alice), note: "system-test")

    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:github] = OmniAuth::AuthHash.new(
      provider: "github",
      uid: "system-test-uid",
      info: { nickname: "newcomer", name: "New Comer", email: "newcomer@example.com" }
    )

    visit "/invites/#{invite.token}"
    assert_text "You've been invited"

    click_button "Continue with GitHub"

    assert_text "Choose your username"

    fill_in "username", with: "newcomer"
    fill_in "full_name", with: "New Comer"
    click_button "Create account"

    assert_text "Welcome, newcomer"

    user = User.find_by(username: "newcomer")
    assert user, "expected new user to be created"
    assert_equal 1, user.identities.count
    assert AuditEvent.where(event_type: "user_created", subject_user: user).exists?
    invite.reload
    assert invite.consumed?
  end
end
