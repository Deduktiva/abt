require "test_helper"
class CustomerPortalHostConstraintTest < ActiveSupport::TestCase
  Req = Struct.new(:host)
  test "matches only the configured customer portal host" do
    c = CustomerPortalHostConstraint.new
    assert c.matches?(Req.new("customer-portal-test.localhost"))
    assert_not c.matches?(Req.new("abt-test.localhost"))
  end
end
