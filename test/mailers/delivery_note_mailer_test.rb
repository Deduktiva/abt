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

  test "customer_email uses salutation_line when exactly one contact resolves as recipient" do
    customer_contacts(:good_eu_accounting).update!(salutation_line: "Sehr geehrter Herr Huber,")

    # good_eu_accounting is the sole contact with receives_delivery_note_emails: true.
    delivery_note = delivery_notes(:published_delivery_note)
    mail = DeliveryNoteMailer.with(delivery_note: delivery_note, skip_attachments: true).customer_email

    assert_equal [ "customer@good-company.co.uk" ], mail.to
    assert_match "Sehr geehrter Herr Huber,", mail.text_part.body.to_s
    assert_match "Sehr geehrter Herr Huber,", mail.html_part.body.to_s
    assert_no_match(/Dear A Good Company B\.V\./, mail.text_part.body.to_s)
  end

  test "customer_email falls back to greeting when the single resolved contact has no salutation_line" do
    delivery_note = delivery_notes(:published_delivery_note)
    mail = DeliveryNoteMailer.with(delivery_note: delivery_note, skip_attachments: true).customer_email

    assert_equal [ "customer@good-company.co.uk" ], mail.to
    assert_match "Dear A Good Company B.V.,", mail.text_part.body.to_s
  end

  test "customer_email falls back to greeting when multiple contacts match, even if both have salutation_line set" do
    # Promote the project-one lead to also receive delivery notes; project one
    # matches both contacts, so neither salutation wins.
    customer_contacts(:good_eu_accounting).update!(salutation_line: "Sehr geehrter Herr A,")
    customer_contacts(:good_eu_project_one_lead).update!(
      salutation_line: "Sehr geehrter Herr B,",
      receives_delivery_note_emails: true
    )

    delivery_note = delivery_notes(:published_delivery_note)
    mail = DeliveryNoteMailer.with(delivery_note: delivery_note, skip_attachments: true).customer_email

    assert_equal 2, mail.to.size
    text_body = mail.text_part.body.to_s
    assert_match "Dear A Good Company B.V.,", text_body
    assert_no_match(/Sehr geehrter Herr A,/, text_body)
    assert_no_match(/Sehr geehrter Herr B,/, text_body)
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
end
