require "application_system_test_case"

class CustomerVatVerificationTest < ApplicationSystemTestCase
  self.use_transactional_tests = false

  setup do
    @original_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :inline
    @customer = customers(:good_eu)
    @customer.update_columns(vat_id_verified_at: nil)
    @customer.vat_verifications.destroy_all
  end

  teardown do
    ActiveJob::Base.queue_adapter = @original_adapter
  end

  test "clicking Verify on a never-verified customer updates the row to verified" do
    ViesVerifier.lookup_strategy = ->(_vat, requester:) {
      {
        valid_response: true,
        request_identifier: "WAPIAAAAabcdef01",
        request_date: Time.current,
        trader_name: @customer.name,
        trader_address: @customer.address,
        country_iso2: @customer.country_iso2
      }
    }

    visit customer_path(@customer)
    assert_selector ".badge.bg-warning", text: "Not verified"

    click_on "Verify"

    assert_text "verified #{I18n.l(Date.current)}"
    assert_no_selector ".badge.bg-warning", text: "Not verified"
  end

  test "clicking Verify on an unregistered VAT ID shows the Invalid per VIES badge" do
    ViesVerifier.lookup_strategy = ->(_vat, requester:) {
      { valid_response: false, error_code: "INVALID" }
    }

    visit customer_path(@customer)
    click_on "Verify"

    assert_selector ".badge.bg-danger", text: "Invalid per VIES"
  end
end
