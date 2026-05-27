require "test_helper"

class ViesVerifierTest < ActiveSupport::TestCase
  setup do
    @customer = customers(:good_eu)
    @customer.update_columns(vat_id: "BE0123456749", vat_id_verified_at: nil)
  end

  test "records a valid verification and stamps customer.vat_id_verified_at" do
    ViesVerifier.lookup_strategy = ->(vat_id, requester:) {
      {
        valid_response: true,
        request_identifier: "WAPIAAAAabcdef99",
        request_date: Date.new(2026, 5, 27),
        trader_name: "A Good Company B.V.",
        trader_address: "Lulzstreet 3/2/1\nLH234234 Shiphol",
        country_iso2: "BE",
        raw: { valid: true }
      }
    }

    verification = ViesVerifier.new(@customer).run!

    assert verification.valid_per_vies?
    assert_equal "BE0123456749", verification.vat_id
    assert_equal "BE", verification.country_iso2
    assert_equal "A Good Company B.V.", verification.trader_name
    assert_equal verification.created_at, @customer.reload.vat_id_verified_at
  end

  test "records an invalid verification without touching vat_id_verified_at" do
    ViesVerifier.lookup_strategy = ->(vat_id, requester:) {
      { valid_response: false, error_code: "INVALID" }
    }

    verification = ViesVerifier.new(@customer).run!

    assert verification.invalid_per_vies?
    assert_equal "INVALID", verification.error_code
    assert_nil @customer.reload.vat_id_verified_at
  end

  test "records a transient row and re-raises on Valvat::MaintenanceError" do
    ViesVerifier.lookup_strategy = ->(*) {
      raise Valvat::ServiceUnavailable.new("SERVICE_UNAVAILABLE", Valvat::Lookup::VIES)
    }

    assert_raises(Valvat::ServiceUnavailable) do
      ViesVerifier.new(@customer).run!
    end

    verification = @customer.vat_verifications.latest_first.first
    assert verification.unavailable?
    assert_equal "Valvat::ServiceUnavailable", verification.error_code
    assert_nil @customer.reload.vat_id_verified_at
  end

  test "associates the verification with the actor user" do
    ViesVerifier.lookup_strategy = ->(*) {
      { valid_response: true, country_iso2: "BE", raw: { valid: true } }
    }

    verification = ViesVerifier.new(@customer, actor: users(:alice)).run!

    assert_equal users(:alice), verification.performed_by_user
  end
end
