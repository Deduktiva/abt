require "test_helper"

class ExpiringOffersMailerTest < ActionMailer::TestCase
  def make_expired_offer
    offer = Offer.create_with_initial_version!(
      matchcode: "exp-mailer-#{SecureRandom.hex(3)}",
      customer: customers(:good_eu),
      state: "draft"
    )
    offer.current_version.offer_milestones.create!(title: "M", trigger: "on_order", net_amount: 1)
    offer.send_current_version!
    offer.update_columns(expires_at: 2.days.ago)
    offer
  end

  test "expiring_report addresses the issuer's auto_bcc with a digest" do
    offer = make_expired_offer
    mail = ExpiringOffersMailer.with(offers: [ offer ]).expiring_report
    assert_equal [ "bcc@example.com" ], mail.to
    assert_match(/expired offer/, mail.subject)
    assert_match offer.document_number, mail.text_part.body.to_s
  end

  test "expiring_report is a no-op when the issuer auto_bcc is blank" do
    IssuerCompany.get_the_issuer!.update!(document_email_auto_bcc: "")
    offer = make_expired_offer
    mail = ExpiringOffersMailer.with(offers: [ offer ]).expiring_report
    assert_nil mail.message_id, "expected mailer to short-circuit when no recipient is configured"
  end
end
