class DeliveryNoteEmailSenderJob < ApplicationJob
  queue_as :default

  def perform(delivery_note_id)
    delivery_note = DeliveryNote.find(delivery_note_id)

    # Send the email
    DeliveryNoteMailer.with(delivery_note: delivery_note).customer_email.deliver_now

    # Mark as sent with current timestamp
    delivery_note.update_column(:email_sent_at, Time.current)
  end
end
