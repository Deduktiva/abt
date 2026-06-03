require "test_helper"

class DeliveryNoteMailerTest < ActionMailer::TestCase
  def setup
    ActionMailer::Base.deliveries.clear
  end

  test "customer_email attaches the rendered PDF by default" do
    delivery_note = delivery_notes(:published_delivery_note)
    mail = DeliveryNoteMailer.with(delivery_note: delivery_note).customer_email

    assert_equal 1, mail.attachments.size
    attachment = mail.attachments.first
    assert_match(/DeliveryNote-#{delivery_note.document_number}\.pdf\z/, attachment.filename)
    assert_equal "application/pdf", attachment.content_type
  end

  test "customer_email falls back to greeting when multiple contacts match" do
    customer_contacts(:good_eu_accounting).update!(salutation_line: "Hi tester one,")
    customer_contacts(:good_eu_project_one_lead).update!(
      salutation_line: "Hi tester two,",
      receives_delivery_note_emails: true
    )

    delivery_note = delivery_notes(:published_delivery_note)
    mail = DeliveryNoteMailer.with(delivery_note: delivery_note, skip_attachments: true).customer_email

    assert_equal 2, mail.to.size
    assert_match "Dear A Good Company B.V.,", mail.text_part.body.to_s
  end

  test "customer_email includes the acceptance upload link when a token is given" do
    dn = delivery_notes(:published_delivery_note)
    token = dn.issue_acceptance_upload_token!
    mail = DeliveryNoteMailer.with(delivery_note: dn, acceptance_token: token, skip_attachments: true).customer_email
    assert_match "/delivery-acceptance/#{token}", mail.body.encoded
  end

  test "customer_email omits the link when no token is given" do
    dn = delivery_notes(:published_delivery_note)
    mail = DeliveryNoteMailer.with(delivery_note: dn, skip_attachments: true).customer_email
    assert_no_match "/delivery-acceptance/", mail.body.encoded
  end

  test "customer_email skips PDF rendering when skip_attachments is set" do
    delivery_note = delivery_notes(:published_delivery_note)

    # If attach_pdf were called, DeliveryNoteRenderer#render would be invoked.
    # Replace it for the duration of this test so any unexpected call surfaces.
    original = DeliveryNoteRenderer.instance_method(:render)
    DeliveryNoteRenderer.define_method(:render) { raise "PDF should not be rendered" }
    begin
      mail = DeliveryNoteMailer.with(delivery_note: delivery_note, skip_attachments: true).customer_email
      assert_not_nil mail.html_part
      assert_equal 0, mail.attachments.size
    ensure
      DeliveryNoteRenderer.define_method(:render, original)
    end
  end

  test "bulk_customer_email renders a per-note acceptance link for eligible notes" do
    dn = delivery_notes(:published_delivery_note)
    token = dn.issue_acceptance_upload_token!

    # Avoid invoking the real FOP renderer for the combined email's attachments.
    original = DeliveryNoteRenderer.instance_method(:render)
    DeliveryNoteRenderer.define_method(:render) { "%PDF-1.4 fake" }
    begin
      mail = DeliveryNoteMailer.with(
        delivery_notes: [ dn ], recipients: [ "x@example.com" ],
        acceptance_tokens: { dn.id.to_s => token }
      ).bulk_customer_email
      assert_match "/delivery-acceptance/#{token}", mail.body.encoded
    ensure
      DeliveryNoteRenderer.define_method(:render, original)
    end
  end
end
