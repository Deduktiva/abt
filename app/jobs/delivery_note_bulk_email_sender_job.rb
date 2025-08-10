class DeliveryNoteBulkEmailSenderJob < ApplicationJob
  queue_as :default

  def perform(delivery_note_ids)
    delivery_notes = DeliveryNote.where(id: delivery_note_ids)

    # All delivery notes should belong to the same customer
    customer = delivery_notes.first.customer
    return unless customer.email.present?

    # Send the bulk email
    DeliveryNoteMailer.with(delivery_notes: delivery_notes).bulk_customer_email.deliver_now

    # Mark all as sent with current timestamp
    delivery_notes.update_all(email_sent_at: Time.current)
  end
end
