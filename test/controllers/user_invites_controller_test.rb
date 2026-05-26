require "test_helper"

class UserInvitesControllerTest < ActionDispatch::IntegrationTest
  skip_default_signin!

  test "create requires authentication" do
    post user_invites_path
    assert_redirected_to new_session_path
  end

  test "create generates an invite and shows URL once" do
    sign_in_as(users(:alice))
    assert_difference -> { UserInvite.where(purpose: UserInvite::PURPOSE_SIGNUP).count }, 1 do
      post user_invites_path
    end
    assert_response :success
    assert_select "code", /\/invites\//
  end
end
