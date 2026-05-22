require 'application_system_test_case'

class UserInvitesTest < ApplicationSystemTestCase
  test 'generating an invite URL renders the token page' do
    visit new_user_invite_path
    assert_selector 'h1', text: 'Invite a new user'

    click_button 'Generate invite URL'

    assert_selector 'h1', text: 'Invite generated'
    assert_selector 'code', text: %r{/invites/}
  end
end
