require "test_helper"

class VerifyCustomerVatIdJobTest < ActiveJob::TestCase
  test "calls the verifier and creates a verification row on the happy path" do
    customer = customers(:good_eu)
    customer.update_columns(vat_id: "BE0123456749")
    ViesVerifier.lookup_strategy = ->(*) {
      { valid_response: true, country_iso2: "BE", raw: { valid: true } }
    }

    assert_difference -> { customer.vat_verifications.count }, 1 do
      VerifyCustomerVatIdJob.perform_now(customer)
    end
  end

  test "does nothing for an inactive customer" do
    customer = customers(:good_eu)
    customer.update_columns(active: false, vat_id: "BE0123456749")

    assert_no_difference -> { customer.vat_verifications.count } do
      VerifyCustomerVatIdJob.perform_now(customer)
    end
  end

  test "does nothing when vat_id is blank" do
    customer = customers(:good_eu)
    customer.update_columns(vat_id: "")
    # also stub the tax class away to clear the presence validator
    customer.update_columns(sales_tax_customer_class_id: sales_tax_customer_classes(:restoftheworld).id)

    assert_no_difference -> { customer.vat_verifications.count } do
      VerifyCustomerVatIdJob.perform_now(customer)
    end
  end
end
