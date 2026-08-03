module DeliveryNotesHelper
  # Renders DeliveryNote#status_badge's { level:, text: } pair, or nothing when
  # the note is in the plain published state that warrants no badge.
  def delivery_note_status_badge_tag(delivery_note)
    badge = delivery_note.status_badge
    return unless badge

    badge_tag(badge[:level], badge[:text])
  end
end
