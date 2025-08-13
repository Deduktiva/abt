import GenericEmailPreviewController from "controllers/generic_email_preview_controller"

// Invoice-specific email preview controller that extends the generic one
export default class extends GenericEmailPreviewController {
  static values = {
    ...GenericEmailPreviewController.values,
    invoiceId: Number,
    previewUrl: String,
    sendUrl: String
  }

  connect() {
    super.connect()
  }
}
