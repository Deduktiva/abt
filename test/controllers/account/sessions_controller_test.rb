require "test_helper"

class Account::SessionsControllerTest < ActionDispatch::IntegrationTest
  test "index lists active sessions" do
    sign_in_as(users(:alice))
    get account_sessions_path
    assert_response :success
  end

  test "destroying another session terminates it but stays signed in" do
    sign_in_as(users(:alice))
    other, _plain = UserSession.create_for!(user: users(:alice), request: nil)

    delete account_session_path(other)
    assert_redirected_to account_sessions_path
    assert other.reload.terminated_at.present?
  end

  test "destroying current session signs the user out" do
    current = sign_in_as(users(:alice))
    delete account_session_path(current)
    assert_redirected_to new_session_path
    assert current.reload.terminated_at.present?
  end
end
