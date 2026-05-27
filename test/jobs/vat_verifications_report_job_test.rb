require "test_helper"

class VatVerificationsReportJobTest < ActiveJob::TestCase
  include ActionMailer::TestHelper

  setup do
    CustomerVatVerification.delete_all
    ActionMailer::Base.deliveries.clear
    @issuer = issuer_companies(:one)
    @issuer.update!(reporting_email: "reports@example.com")

    # Only @customer is in scope by default; nudge the other vat_id_required
    # customers out so each test controls its own scope.
    @customer = customers(:good_eu)
    @customer.update_columns(vat_id: "BE0123456749", vat_id_verified_at: nil)
    Customer.where.not(id: @customer.id).update_all(active: false)
  end

  def make_verification(valid:, created_at:, notified_at: nil, customer: @customer, error_code: nil)
    CustomerVatVerification.create!(
      customer: customer, vat_id: customer.vat_id,
      country_iso2: customer.country_iso2,
      valid_response: valid, error_code: error_code,
      raw_response: "{}", created_at: created_at, notified_at: notified_at
    )
  end

  test "reports a newly-invalid verification that follows a valid one" do
    make_verification(valid: true, created_at: 10.days.ago)
    new_invalid = make_verification(valid: false, created_at: 1.hour.ago)

    assert_emails 1 do
      VatVerificationsReportJob.perform_now
    end
    mail = ActionMailer::Base.deliveries.last
    assert_match @customer.matchcode, mail.html_part.body.to_s
    assert_not_nil new_invalid.reload.notified_at
  end

  test "reports a first-ever-invalid verification with no priors" do
    new_invalid = make_verification(valid: false, created_at: 1.hour.ago)

    assert_emails 1 do
      VatVerificationsReportJob.perform_now
    end
    assert_match @customer.matchcode, ActionMailer::Base.deliveries.last.html_part.body.to_s
    assert_not_nil new_invalid.reload.notified_at
  end

  test "reports an invalid verification that follows only unavailable priors" do
    make_verification(valid: nil, created_at: 3.days.ago, error_code: "MS_UNAVAILABLE")
    new_invalid = make_verification(valid: false, created_at: 1.hour.ago)

    assert_emails 1 do
      VatVerificationsReportJob.perform_now
    end
    assert_not_nil new_invalid.reload.notified_at
  end

  test "does not re-report a customer who was already invalid (continuation)" do
    make_verification(valid: true, created_at: 30.days.ago)
    make_verification(valid: false, created_at: 5.days.ago, notified_at: 5.days.ago)
    continuation = make_verification(valid: false, created_at: 1.hour.ago)

    assert_no_emails do
      VatVerificationsReportJob.perform_now
    end
    # Continuation row gets marked so the partial index does not grow unbounded.
    assert_not_nil continuation.reload.notified_at
  end

  test "does not report and does not mark recovery (invalid -> valid)" do
    make_verification(valid: false, created_at: 5.days.ago, notified_at: 5.days.ago)
    recovery = make_verification(valid: true, created_at: 1.hour.ago)

    assert_no_emails do
      VatVerificationsReportJob.perform_now
    end
    assert_not_nil recovery.reload.notified_at
  end

  test "reports stuck-unavailable when the streak is at least the threshold" do
    8.downto(0) do |days_ago|
      make_verification(valid: nil, created_at: days_ago.days.ago,
                        error_code: "MS_UNAVAILABLE")
    end
    latest = CustomerVatVerification.order(:created_at).last

    assert_emails 1 do
      VatVerificationsReportJob.perform_now
    end
    mail = ActionMailer::Base.deliveries.last
    assert_match "MS_UNAVAILABLE", mail.html_part.body.to_s
    assert_not_nil latest.reload.notified_at
  end

  test "does not report stuck-unavailable when the streak is below the threshold" do
    3.downto(0) do |days_ago|
      make_verification(valid: nil, created_at: days_ago.days.ago + 1.minute,
                        error_code: "MS_UNAVAILABLE")
    end

    assert_no_emails do
      VatVerificationsReportJob.perform_now
    end
  end

  test "does not re-report stuck-unavailable continuation after first notification" do
    make_verification(valid: nil, created_at: 8.days.ago, notified_at: 8.days.ago,
                      error_code: "MS_UNAVAILABLE")
    7.downto(0) do |days_ago|
      make_verification(valid: nil, created_at: days_ago.days.ago + 1.minute,
                        error_code: "MS_UNAVAILABLE")
    end

    assert_no_emails do
      VatVerificationsReportJob.perform_now
    end
  end

  test "skips inactive customers" do
    @customer.update_columns(active: false)
    make_verification(valid: false, created_at: 1.hour.ago)

    assert_no_emails do
      VatVerificationsReportJob.perform_now
    end
  end

  test "skips customers whose tax class does not require a vat_id" do
    @customer.update_columns(
      sales_tax_customer_class_id: sales_tax_customer_classes(:restoftheworld).id
    )
    make_verification(valid: false, created_at: 1.hour.ago)

    assert_no_emails do
      VatVerificationsReportJob.perform_now
    end
  end

  test "running twice in succession does not send a duplicate email" do
    make_verification(valid: true, created_at: 10.days.ago)
    make_verification(valid: false, created_at: 1.hour.ago)

    assert_emails 1 do
      VatVerificationsReportJob.perform_now
    end
    assert_no_emails do
      VatVerificationsReportJob.perform_now
    end
  end

  test "sends nothing when reporting_email is blank" do
    @issuer.update!(reporting_email: "")
    make_verification(valid: false, created_at: 1.hour.ago)

    assert_no_emails do
      VatVerificationsReportJob.perform_now
    end
  end
end
