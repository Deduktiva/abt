require "test_helper"
class AppHostConstraintTest < ActiveSupport::TestCase
  Req = Struct.new(:host)

  test "matches every host except the configured customer portal host" do
    c = AppHostConstraint.new
    assert c.matches?(Req.new("abt-test.localhost"))
    assert c.matches?(Req.new("www.example.com"))
    assert_not c.matches?(Req.new("customer-portal-test.localhost"))
  end

  test "matches every host when no customer portal host is configured" do
    c = AppHostConstraint.new
    original = Settings.customer_portal.host
    Settings.customer_portal.host = nil
    assert c.matches?(Req.new("customer-portal-test.localhost"))
    assert c.matches?(Req.new("anything.example.com"))
  ensure
    Settings.customer_portal.host = original
  end
end
