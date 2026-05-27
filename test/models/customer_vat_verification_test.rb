require "test_helper"

class CustomerVatVerificationTest < ActiveSupport::TestCase
  test "predicates reflect valid_response state" do
    truthy = customer_vat_verifications(:good_eu_valid)
    falsy = customer_vat_verifications(:good_national_invalid)
    transient = CustomerVatVerification.create!(
      customer: customers(:good_eu), vat_id: "BE0123456749",
      valid_response: nil, error_code: "MS_UNAVAILABLE"
    )

    assert truthy.valid_per_vies?
    assert_not truthy.invalid_per_vies?
    assert_not truthy.unavailable?

    assert falsy.invalid_per_vies?
    assert_not falsy.valid_per_vies?
    assert_not falsy.unavailable?

    assert transient.unavailable?
    assert_not transient.valid_per_vies?
    assert_not transient.invalid_per_vies?
  end

  test "latest_first orders by created_at desc" do
    customer = customers(:good_eu)
    older = customer_vat_verifications(:good_eu_valid)
    newer = CustomerVatVerification.create!(customer: customer, vat_id: "BE0123456749", valid_response: true, created_at: 1.day.from_now)
    assert_equal [ newer, older ], customer.vat_verifications.latest_first.to_a
  end
end
