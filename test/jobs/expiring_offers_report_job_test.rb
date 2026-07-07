require "test_helper"

class ExpiringOffersReportJobTest < ActiveJob::TestCase
  include ActiveJob::TestHelper
  include ActionMailer::TestHelper

  test "expires past-validity sent offers and sends one digest" do
    offer = offers(:sent_offer)
    offer.update!(expires_at: Date.yesterday)
    assert_emails 1 do
      ExpiringOffersReportJob.perform_now
    end
    offer.reload
    assert offer.expired?
    assert_not_nil offer.reported_expired_at
  end

  test "digest covers multiple expiring offers in a single email with full content" do
    offer1 = offers(:sent_offer)
    offer1.update!(expires_at: Date.yesterday)

    offer2 = create_offer_with_milestone(customer: customers(:good_national))
    version2 = offer2.draft_version
    version2.update!(
      sent_at: Time.current,
      date: Date.current,
      customer_name: offer2.customer.name,
      customer_address: offer2.customer.address,
      customer_country_iso2: offer2.customer.country_iso2,
      payment_terms_days: offer2.customer.payment_terms_days
    )
    offer2.update!(state: "sent", document_number: "20269002", expires_at: Date.yesterday)

    assert_emails 1 do
      ExpiringOffersReportJob.perform_now
    end

    issuer = issuer_companies(:one)
    delivered = ActionMailer::Base.deliveries.last
    assert_equal [ issuer.reporting_email ], delivered.to
    assert_equal I18n.t("mailers.expiring_offers.subject", issuer_name: issuer.short_name, count: 2), delivered.subject

    html = delivered.html_part.body.to_s
    text = delivered.text_part.body.to_s

    [ offer1, offer2 ].each do |offer|
      offer.reload
      version = offer.current_sent_version
      offer_url = AbsoluteUrl.offer(offer)
      [ html, text ].each do |body|
        assert_match offer.document_number, body
        assert_match offer.customer.name, body
        assert_match offer.expires_at.strftime("%d.%m.%Y"), body
        assert_match sprintf("%.2f", version.sum_net), body
        assert_match offer_url, body
      end
      assert_match %r{href="#{Regexp.escape(offer_url)}"}, html
      assert offer.expired?
    end
  end

  test "no-op when nothing expired" do
    offer = offers(:sent_offer)
    offer.update!(expires_at: Date.tomorrow)
    assert_emails 0 do
      ExpiringOffersReportJob.perform_now
    end
    offer.reload
    assert offer.sent?
    assert_nil offer.reported_expired_at
  end

  test "already-reported offers are not re-reported" do
    offer = offers(:sent_offer)
    offer.update!(state: "expired", expires_at: Date.yesterday, reported_expired_at: Time.current)
    assert_emails 0 do
      ExpiringOffersReportJob.perform_now
    end
  end

  test "re-expires an offer that was rejected and reopened after auto-expiry" do
    offer = offers(:sent_offer)
    offer.update!(state: "expired", expires_at: Date.yesterday, reported_expired_at: Time.current)
    offer.reject!
    offer.reopen!

    assert_emails 1 do
      ExpiringOffersReportJob.perform_now
    end
    assert offer.reload.expired?
  end

  test "drafts and accepted offers are untouched" do
    offers(:sent_offer).accept!(order_number: "PO", ordered_on: Date.current)
    offers(:sent_offer).update!(expires_at: Date.yesterday)
    assert_emails 0 do
      ExpiringOffersReportJob.perform_now
    end
    assert offers(:sent_offer).reload.accepted?
  end
end
