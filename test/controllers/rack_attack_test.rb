require 'test_helper'

class RackAttackTest < ActiveSupport::TestCase
  test 'ip_key buckets IPv6 addresses by /64' do
    same_64      = %w[2001:db8::1 2001:db8::ffff:ffff]
    different_64 = '2001:db8:1::1'
    ipv4         = '203.0.113.7'

    keys = same_64.map { |ip| Rack::Attack.ip_key(stub_req(ip)) }
    assert_equal keys.first, keys.last, 'two addresses inside one /64 must share a bucket'
    refute_equal keys.first, Rack::Attack.ip_key(stub_req(different_64)),
                 'different /64s must have distinct buckets'
    assert_equal ipv4, Rack::Attack.ip_key(stub_req(ipv4)),
                 'IPv4 addresses are not masked'
  end

  test 'client_ip prefers action_dispatch.remote_ip over rack req.ip' do
    env = { 'action_dispatch.remote_ip' => '203.0.113.7',
            'REMOTE_ADDR' => '10.0.0.5',
            'HTTP_X_FORWARDED_FOR' => '1.2.3.4' }
    assert_equal '203.0.113.7', Rack::Attack.client_ip(stub_req(env))
  end

  private

  def stub_req(env_or_ip)
    env = env_or_ip.is_a?(Hash) ? env_or_ip : { 'action_dispatch.remote_ip' => env_or_ip }
    Struct.new(:env) do
      def ip
        env['REMOTE_ADDR'] || '127.0.0.1'
      end
    end.new(env)
  end
end
