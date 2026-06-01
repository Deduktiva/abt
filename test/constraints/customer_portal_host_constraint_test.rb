require "test_helper"
class CustomerPortalHostConstraintTest < ActiveSupport::TestCase
  Req = Struct.new(:host)
  test "matches only the configured customer portal host" do
    c = CustomerPortalHostConstraint.new
    assert c.matches?(Req.new("customer-portal.example.test"))
    assert_not c.matches?(Req.new("www.example.com"))
  end
end
