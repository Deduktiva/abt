module DeliveryNotesHelper
  # Renders DeliveryNote#status_badge's { level:, text: } pair. Interpolating
  # the level into the class in the template trips brakeman, so the mapping
  # lives here as a literal lookup.
  def delivery_note_status_badge_tag(delivery_note)
    badge = delivery_note.status_badge
    return unless badge

    bg = { info: "bg-info", success: "bg-success", warning: "bg-warning", danger: "bg-secondary" }.fetch(badge[:level])
    content_tag(:span, badge[:text], class: "badge #{bg}")
  end
end
