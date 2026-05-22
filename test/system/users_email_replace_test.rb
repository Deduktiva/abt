require 'application_system_test_case'

class UsersEmailReplaceTest < ApplicationSystemTestCase
  setup do
    @user = users(:alice)
    @email = user_emails(:alice_primary)
  end

  test "Replace button reveals replacement form" do
    visit user_path(@user)

    panel_selector = "#replace-email-#{@email.id}"

    assert_selector "#{panel_selector}.d-none", visible: :all
    assert_no_selector "#{panel_selector}:not(.d-none)"

    within("li", text: @email.address) do
      click_button 'Replace…'
    end

    assert_selector "#{panel_selector}:not(.d-none)"
    within(panel_selector) do
      assert_selector "input[type='email']"
      assert_button 'Replace'
    end
  end

  test "Replace button toggles the form closed again" do
    visit user_path(@user)
    panel_selector = "#replace-email-#{@email.id}"

    within("li", text: @email.address) do
      click_button 'Replace…'
    end
    assert_selector "#{panel_selector}:not(.d-none)"

    within("li", text: @email.address) do
      click_button 'Replace…'
    end
    assert_selector "#{panel_selector}.d-none", visible: :all
  end
end
