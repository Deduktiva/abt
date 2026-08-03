module EmailPreviewHelper
  # Stimulus data attributes that wire an element up to the
  # generic-email-preview controller for a given Invoice or DeliveryNote.
  # Relies on the routes following the {action}_{resource}_path convention.
  # The controller-side counterpart — building the previewed payload — is
  # EmailPreviewExtraction.
  def email_preview_data(resource)
    prefix = resource.class.name.underscore
    {
      controller: "generic-email-preview",
      "generic-email-preview-preview-url-value" => send("preview_email_#{prefix}_path", resource),
      "generic-email-preview-html-preview-url-value" => send("preview_email_html_#{prefix}_path", resource),
      "generic-email-preview-send-url-value" => send("send_email_#{prefix}_path", resource)
    }
  end
end
