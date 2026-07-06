require "test_helper"

class OfferMailerTest < ActionMailer::TestCase
  setup do
    ActionMailer::Base.deliveries.clear
    @offer = offers(:sent_offer)
    version = @offer.versions.find_by(version_number: 1)
    attachment = Attachment.new(title: "Offer PDF")
    attachment.set_data("%PDF-stored", "application/pdf")
    attachment.filename = "offer.pdf"
    attachment.save!
    version.update!(attachment: attachment)
  end

  test "sends to offer-flagged contacts with the stored PDF attached" do
    mail = OfferMailer.with(offer: @offer).customer_email

    # good_eu's only offer-flagged contact is eu_contact (offers@good-company.co.uk).
    assert_equal [ "offers@good-company.co.uk" ], mail.to
    assert_equal 1, mail.attachments.size
    assert_equal "offer.pdf", mail.attachments.first.filename
    assert_equal "%PDF-stored", mail.attachments.first.body.raw_source
  end

  test "customer_email skips attaching the stored PDF when skip_attachments is set" do
    mail = OfferMailer.with(offer: @offer, skip_attachments: true).customer_email

    assert_equal 0, mail.attachments.size
  end

  test "salutation override on the sent version wins over the contact salutation" do
    @offer.current_sent_version.update!(salutation_override: "Dear override,")
    mail = OfferMailer.with(offer: @offer).customer_email

    assert_includes mail.text_part.body.to_s, "Dear override,"
    assert_includes mail.html_part.body.to_s, "Dear override,"
  end

  test "customer_email falls back to greeting when the contact has no salutation_line" do
    mail = OfferMailer.with(offer: @offer).customer_email

    assert_match "Dear A Good Company B.V.,", mail.text_part.body.to_s
    assert_match "Dear A Good Company B.V.,", mail.html_part.body.to_s
  end

  test "no-op when no contact opted in" do
    @offer.customer.customer_contacts.update_all(receives_offer_emails: false)
    mail = OfferMailer.with(offer: @offer).customer_email

    assert_nil mail.to
    assert_instance_of ActionMailer::Base::NullMail, mail.message
  end

  test "customer_email subject includes the issuer and offer document number" do
    mail = OfferMailer.with(offer: @offer).customer_email

    assert_equal "My Example Offer #{@offer.document_number}", mail.subject
  end

  test "customer_email HTML and text templates include the offer subject line" do
    @offer.current_sent_version.update!(subject: "Website redesign proposal")
    mail = OfferMailer.with(offer: @offer).customer_email

    assert_match "Website redesign proposal", mail.html_part.body.to_s
    assert_match "Website redesign proposal", mail.text_part.body.to_s
  end
end
