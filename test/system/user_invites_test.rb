require "application_system_test_case"

class UserInvitesTest < ApplicationSystemTestCase
  test "clicking + Invite user on the users page lands directly on the token page" do
    visit users_path
    assert_selector ".breadcrumb-item.active", text: "Users"

    click_button "+ Invite user"

    assert_selector "h1", text: "Invite generated"
    assert_selector "code", text: %r{/invites/}
  end
end
