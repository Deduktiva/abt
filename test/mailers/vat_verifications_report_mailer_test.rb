require "test_helper"

class VatVerificationsReportMailerTest < ActionMailer::TestCase
  def setup
    ActionMailer::Base.deliveries.clear
    @issuer = issuer_companies(:one)
    @issuer.update!(reporting_email: "reports@example.com")

    @customer_a = customers(:good_eu)
    @customer_a.update_columns(vat_id: "BE0123456749")
    @customer_b = customers(:good_national)

    @newly_invalid = [
      CustomerVatVerification.create!(
        customer: @customer_a, vat_id: "BE0123456749", country_iso2: "BE",
        valid_response: false, error_code: "INVALID", raw_response: "{}",
        created_at: 1.hour.ago
      )
    ]
    @stuck = [
      CustomerVatVerification.create!(
        customer: @customer_b, vat_id: "NAT0000000", country_iso2: "NL",
        valid_response: nil, error_code: "MS_UNAVAILABLE", raw_response: "{}",
        created_at: 1.hour.ago
      )
    ]
  end

  test "daily_report builds an email to reporting_email with both sections in the subject" do
    mail = VatVerificationsReportMailer.with(newly_invalid: @newly_invalid, stuck_unavailable: @stuck).daily_report

    assert_equal [ "reports@example.com" ], mail.to
    assert_equal [ "from@example.com" ], mail.from
    assert_match(/My Example/, mail.subject)
    assert_match(/VAT/, mail.subject)
  end

  test "daily_report HTML body lists every customer in both sections" do
    mail = VatVerificationsReportMailer.with(newly_invalid: @newly_invalid, stuck_unavailable: @stuck).daily_report
    html = mail.html_part.body.to_s

    assert_match @customer_a.matchcode, html
    assert_match "BE0123456749", html
    assert_match @customer_b.matchcode, html
    assert_match "NAT0000000", html
  end

  test "daily_report text body lists every customer in both sections" do
    mail = VatVerificationsReportMailer.with(newly_invalid: @newly_invalid, stuck_unavailable: @stuck).daily_report
    text = mail.text_part.body.to_s

    assert_match @customer_a.matchcode, text
    assert_match @customer_b.matchcode, text
  end

  test "daily_report returns NullMail when issuer has no reporting_email" do
    @issuer.update!(reporting_email: "")

    mail = VatVerificationsReportMailer.with(newly_invalid: @newly_invalid, stuck_unavailable: @stuck).daily_report

    assert_instance_of ActionMailer::Parameterized::MessageDelivery, mail
    assert_instance_of ActionMailer::Base::NullMail, mail.message
  end

  test "daily_report returns NullMail when both event lists are empty" do
    mail = VatVerificationsReportMailer.with(newly_invalid: [], stuck_unavailable: []).daily_report

    assert_instance_of ActionMailer::Parameterized::MessageDelivery, mail
    assert_instance_of ActionMailer::Base::NullMail, mail.message
  end
end
