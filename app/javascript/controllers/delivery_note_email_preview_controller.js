import GenericEmailPreviewController from "controllers/generic_email_preview_controller"

// Delivery Note-specific email preview controller that extends the generic one
export default class extends GenericEmailPreviewController {
  static values = {
    ...GenericEmailPreviewController.values,
    deliveryNoteId: Number
  }

  connect() {
    super.connect()

    // Set the URLs based on delivery note ID
    this.previewUrlValue = `/delivery_notes/${this.deliveryNoteIdValue}/preview_email`
    this.sendUrlValue = `/delivery_notes/${this.deliveryNoteIdValue}/send_email`
  }
}
