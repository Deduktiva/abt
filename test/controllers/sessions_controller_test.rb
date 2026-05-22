require 'test_helper'

class SessionsControllerTest < ActionDispatch::IntegrationTest
  skip_default_signin!

  test 'new is accessible without authentication' do
    get new_session_path
    assert_response :success
  end

  test 'options stashes challenge for a known user' do
    post options_session_path, params: { username: 'alice' }, as: :json
    assert_response :success
    body = JSON.parse(response.body)
    assert body['challenge'].present?
  end

  test 'options returns options even for unknown username (no enumeration)' do
    post options_session_path, params: { username: 'ghost' }, as: :json
    assert_response :success
  end

  test 'destroy signs out and clears cookie' do
    sign_in_as(users(:alice))
    delete session_path
    assert_redirected_to new_session_path
    assert cookies[ApplicationController::SESSION_COOKIE].blank?
  end
end
