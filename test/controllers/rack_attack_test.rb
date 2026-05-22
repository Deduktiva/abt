require 'test_helper'

class RackAttackTest < ActionDispatch::IntegrationTest
  skip_default_signin!

  setup do
    Rack::Attack.cache.store.clear
  end

  teardown do
    Rack::Attack.cache.store.clear
  end

  test 'auth-post throttle limits POST /session/options to 30 per minute per IP' do
    30.times do
      post options_session_path, params: { username: 'alice' }, as: :json
      assert_response :success
    end

    post options_session_path, params: { username: 'alice' }, as: :json
    assert_response :too_many_requests
    body = JSON.parse(response.body)
    assert_equal 'Rate limit exceeded. Please try again later.', body['error']
    assert response.headers['retry-after'].present?
  end

  test 'auth-post throttle covers POST /invites/:token/options' do
    30.times do
      post options_invite_path(token: 'pending-signup-token'),
           params: { username: '', full_name: '', email: '' },
           as: :json
    end

    post options_invite_path(token: 'pending-signup-token'),
         params: { username: '', full_name: '', email: '' },
         as: :json
    assert_response :too_many_requests
  end

  test 'token-fetch throttle limits GET /invites/:token to 60 per minute per IP' do
    60.times do
      get invite_path(token: 'totally-bogus')
    end

    get invite_path(token: 'totally-bogus')
    assert_response :too_many_requests
  end

  test 'token-fetch throttle covers GET /account/email_confirmations/:token' do
    60.times do
      get account_email_confirmation_path(token: 'bogus-token')
    end

    get account_email_confirmation_path(token: 'bogus-token')
    assert_response :too_many_requests
  end

  test 'requests below the limit are not throttled' do
    5.times do
      post options_session_path, params: { username: 'alice' }, as: :json
      assert_response :success
    end
  end

  test 'GET /session/new is not throttled by auth-post rule (different IPs would normally hit other rules)' do
    # The auth-post rule only matches POSTs, so GETs flow through.
    get new_session_path
    assert_response :success
  end
end
