import GenericEmailPreviewController from "controllers/generic_email_preview_controller"

// Delivery Note-specific email preview controller that extends the generic one
export default class extends GenericEmailPreviewController {
  static values = {
    ...GenericEmailPreviewController.values,
    deliveryNoteId: Number,
    previewUrl: String,
    sendUrl: String
  }

  connect() {
    super.connect()
  }
}
