require "test_helper"

# Exercises ScopedThroughCustomer.available_customers once, via the Invoice
# model. DeliveryNote and Offer include the same concern.
class ScopedThroughCustomerTest < ActiveSupport::TestCase
  setup do
    @user = users(:alice)
    @customer = customers(:good_eu)
    create_draft_invoice(customer: @customer, cust_reference: "AVAIL")
  end

  test "available_customers lists active customers owning a visible document" do
    assert_includes Invoice.available_customers(@user), @customer
  end

  test "available_customers drops an inactive customer" do
    @customer.update!(active: false)

    assert_not_includes Invoice.available_customers(@user), @customer
  end

  test "available_customers keeps an inactive customer named by including" do
    @customer.update!(active: false)

    assert_includes Invoice.available_customers(@user, including: @customer.id), @customer
  end

  test "available_customers omits customers without a visible document" do
    assert_not_includes Invoice.available_customers(@user), customers(:offer_only_customer)
  end
end
