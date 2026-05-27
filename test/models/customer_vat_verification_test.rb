require "test_helper"

class CustomerVatVerificationTest < ActiveSupport::TestCase
  test "valid_per_vies? reflects valid_response=true" do
    assert customer_vat_verifications(:good_eu_valid).valid_per_vies?
    assert_not customer_vat_verifications(:good_eu_valid).invalid_per_vies?
    assert_not customer_vat_verifications(:good_eu_valid).unavailable?
  end

  test "invalid_per_vies? reflects valid_response=false" do
    assert customer_vat_verifications(:good_national_invalid).invalid_per_vies?
    assert_not customer_vat_verifications(:good_national_invalid).valid_per_vies?
    assert_not customer_vat_verifications(:good_national_invalid).unavailable?
  end

  test "unavailable? reflects valid_response=nil" do
    transient = CustomerVatVerification.create!(
      customer: customers(:good_eu),
      vat_id: "BE0123456749",
      country_iso2: "BE",
      valid_response: nil,
      error_code: "MS_UNAVAILABLE"
    )
    assert transient.unavailable?
  end

  test "latest_first orders by created_at desc" do
    customer = customers(:good_eu)
    older = customer_vat_verifications(:good_eu_valid)
    newer = CustomerVatVerification.create!(customer: customer, vat_id: "BE0123456749", valid_response: true, created_at: 1.day.from_now)
    assert_equal [ newer, older ], customer.vat_verifications.latest_first.to_a
  end
end
