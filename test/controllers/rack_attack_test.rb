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
    assert_equal 'no-store', response.headers['cache-control']
  end

  test 'webauthn-verify throttle limits POST /session/verify to 10 per minute per IP' do
    10.times do
      post verify_session_path, params: { credential: {} }, as: :json
      # verify returns 422 on bad payloads; that is fine, it still consumes
      # the budget.
      assert_response :unprocessable_content
    end

    post verify_session_path, params: { credential: {} }, as: :json
    assert_response :too_many_requests
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

  test 'session-new throttle limits GET /session/new to 60 per minute per IP' do
    60.times do
      get new_session_path
      assert_response :success
    end

    get new_session_path
    assert_response :too_many_requests
  end

  test 'token-fetch throttle limits GET /invites/:token to 60 per minute per IP' do
    60.times { get invite_path(token: 'totally-bogus') }

    get invite_path(token: 'totally-bogus')
    assert_response :too_many_requests
  end

  test 'token-fetch throttle covers GET /account/email_confirmations/:token' do
    60.times { get account_email_confirmation_path(token: 'bogus-token') }

    get account_email_confirmation_path(token: 'bogus-token')
    assert_response :too_many_requests
  end

  test 'requests below the limit are not throttled' do
    5.times do
      post options_session_path, params: { username: 'alice' }, as: :json
      assert_response :success
    end
  end

  test '429 negotiates an HTML body when the client only accepts text/html' do
    31.times do
      post options_session_path, params: { username: 'alice' },
                                 headers: { 'Accept' => 'text/html' }
    end

    assert_response :too_many_requests
    assert_match %r{text/html}, response.headers['content-type']
    assert_includes response.body, 'Too many requests'
  end

  test 'persistent violators are banned for an hour after 5 throttle violations' do
    # Burn through the auth-post budget once...
    30.times { post options_session_path, params: { username: 'alice' }, as: :json }

    # ...then trigger 5 throttle violations.
    5.times do
      post options_session_path, params: { username: 'alice' }, as: :json
      assert_response :too_many_requests
    end

    # Any further request - even one the throttle would normally allow -
    # gets a 403 from the blocklist.
    get new_session_path
    assert_response :forbidden
  end

  test 'ip_key buckets IPv6 addresses by /64' do
    env_v6 = { 'action_dispatch.remote_ip' => '2001:db8::1' }
    env_v6_same_64 = { 'action_dispatch.remote_ip' => '2001:db8::ffff:ffff' }
    env_v6_different_64 = { 'action_dispatch.remote_ip' => '2001:db8:1::1' }
    env_v4 = { 'action_dispatch.remote_ip' => '203.0.113.7' }

    key1 = Rack::Attack.ip_key(stub_req(env_v6))
    key2 = Rack::Attack.ip_key(stub_req(env_v6_same_64))
    key3 = Rack::Attack.ip_key(stub_req(env_v6_different_64))
    key4 = Rack::Attack.ip_key(stub_req(env_v4))

    assert_equal key1, key2, 'two addresses inside one /64 must share a bucket'
    refute_equal key1, key3, 'different /64s must have distinct buckets'
    assert_equal '203.0.113.7', key4, 'IPv4 addresses are not masked'
  end

  test 'client_ip prefers action_dispatch.remote_ip over rack req.ip' do
    env = {
      'action_dispatch.remote_ip' => '203.0.113.7',
      'REMOTE_ADDR' => '10.0.0.5',
      'HTTP_X_FORWARDED_FOR' => '1.2.3.4'
    }
    assert_equal '203.0.113.7', Rack::Attack.client_ip(stub_req(env))
  end

  private

  def stub_req(env)
    Struct.new(:env) do
      def ip
        env['REMOTE_ADDR'] || '127.0.0.1'
      end
    end.new(env)
  end
end
