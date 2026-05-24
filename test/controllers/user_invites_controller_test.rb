require "test_helper"

class UserInvitesControllerTest < ActionDispatch::IntegrationTest
  skip_default_signin!

  test "new requires authentication" do
    get new_user_invite_path
    assert_redirected_to new_session_path
  end

  test "new shows the form when signed in" do
    sign_in_as(users(:alice))
    get new_user_invite_path
    assert_response :success
  end

  test "create generates an invite and shows URL once" do
    sign_in_as(users(:alice))
    assert_difference -> { UserInvite.where(purpose: UserInvite::PURPOSE_SIGNUP).count }, 1 do
      post user_invites_path
    end
    assert_response :success
    assert_select "code", /\/invites\//
  end

  test "new form opts out of Turbo so the rendered token page survives" do
    sign_in_as(users(:alice))
    get new_user_invite_path
    assert_response :success
    assert_select 'form[action=?][data-turbo="false"]', user_invites_path
  end
end
