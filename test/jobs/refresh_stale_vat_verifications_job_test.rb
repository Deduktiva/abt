require "test_helper"

class RefreshStaleVatVerificationsJobTest < ActiveJob::TestCase
  include ActiveJob::TestHelper

  setup do
    # Start from a clean slate so we only see rows our tests enqueue.
    CustomerVatVerification.delete_all
    @recheck_days = IssuerCompany.get_the_issuer!.vat_id_recheck_days
    # Only `good_eu` should be eligible by default; nudge the other tax-class
    # required customers out of the cohort so each test controls its own scope.
    Customer.where.not(id: customers(:good_eu).id).update_all(active: false)
    @customer = customers(:good_eu)
    @customer.update_columns(vat_id: "BE0123456749", vat_id_verified_at: nil)
  end

  test "enqueues nothing when no customers require verification" do
    @customer.update_columns(active: false)

    assert_no_enqueued_jobs only: VerifyCustomerVatIdJob do
      RefreshStaleVatVerificationsJob.perform_now
    end
  end

  test "enqueues a customer with no prior verification" do
    assert_enqueued_with(job: VerifyCustomerVatIdJob, args: [ @customer ]) do
      RefreshStaleVatVerificationsJob.perform_now
    end
  end

  test "enqueues a customer whose latest valid verification is older than recheck_days" do
    CustomerVatVerification.create!(
      customer: @customer, vat_id: "BE0123456749", valid_response: true,
      created_at: (@recheck_days + 1).days.ago
    )

    assert_enqueued_with(job: VerifyCustomerVatIdJob, args: [ @customer ]) do
      RefreshStaleVatVerificationsJob.perform_now
    end
  end

  test "skips a customer whose latest valid verification is fresher than recheck_days" do
    CustomerVatVerification.create!(
      customer: @customer, vat_id: "BE0123456749", valid_response: true,
      created_at: (@recheck_days - 1).days.ago
    )

    assert_no_enqueued_jobs only: VerifyCustomerVatIdJob do
      RefreshStaleVatVerificationsJob.perform_now
    end
  end

  test "skips an inactive customer" do
    @customer.update_columns(active: false)

    assert_no_enqueued_jobs only: VerifyCustomerVatIdJob do
      RefreshStaleVatVerificationsJob.perform_now
    end
  end

  test "skips a customer whose tax class does not require a vat_id" do
    @customer.update_columns(
      sales_tax_customer_class_id: sales_tax_customer_classes(:restoftheworld).id,
      vat_id: ""
    )

    assert_no_enqueued_jobs only: VerifyCustomerVatIdJob do
      RefreshStaleVatVerificationsJob.perform_now
    end
  end

  test "enqueues a customer whose latest transient verification is older than 24h" do
    CustomerVatVerification.create!(
      customer: @customer, vat_id: "BE0123456749", valid_response: nil,
      error_code: "MS_UNAVAILABLE", created_at: 25.hours.ago
    )

    assert_enqueued_with(job: VerifyCustomerVatIdJob, args: [ @customer ]) do
      RefreshStaleVatVerificationsJob.perform_now
    end
  end

  test "skips a customer whose latest transient verification is fresher than 24h" do
    CustomerVatVerification.create!(
      customer: @customer, vat_id: "BE0123456749", valid_response: nil,
      error_code: "MS_UNAVAILABLE", created_at: 1.hour.ago
    )

    assert_no_enqueued_jobs only: VerifyCustomerVatIdJob do
      RefreshStaleVatVerificationsJob.perform_now
    end
  end
end
