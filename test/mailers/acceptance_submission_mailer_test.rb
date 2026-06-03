require "test_helper"

class AcceptanceSubmissionMailerTest < ActionMailer::TestCase
  test "submitted notifies the issuer reporting_email with a link to the note" do
    dn = delivery_notes(:published_delivery_note)
    mail = AcceptanceSubmissionMailer.with(delivery_note: dn).submitted
    assert_equal [ IssuerCompany.get_the_issuer!.reporting_email ], mail.to
    assert_match dn.document_number, mail.body.encoded
  end
end
