require "test_helper"

class UserAuditEventTest < ActiveSupport::TestCase
  test "record! creates row with action, user, actor, metadata" do
    request = Struct.new(:remote_ip, :user_agent).new("198.51.100.5", "TestUA")
    event = UserAuditEvent.record!(
      action: "login_success",
      user: users(:alice),
      actor: users(:alice),
      request: request,
      metadata: { foo: "bar", n: 1 }
    )
    assert_equal "login_success", event.action
    assert_equal users(:alice), event.user
    assert_equal users(:alice), event.actor
    assert_equal "198.51.100.5", event.ip_address
    assert_equal({ "foo" => "bar", "n" => 1 }, event.metadata)
  end

  test "for_user returns events where user is subject or actor" do
    UserAuditEvent.record!(action: "a", user: users(:alice), actor: users(:bob))
    UserAuditEvent.record!(action: "b", user: users(:bob), actor: users(:alice))
    events = UserAuditEvent.for_user(users(:alice))
    assert_equal 2, events.count
  end

  test "metadata is compacted to drop nil entries" do
    event = UserAuditEvent.record!(action: "x", user: users(:alice), metadata: { a: 1, b: nil })
    assert_equal({ "a" => 1 }, event.metadata)
  end
end
