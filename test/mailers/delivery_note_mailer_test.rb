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
