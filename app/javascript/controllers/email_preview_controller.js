import GenericEmailPreviewController from "./generic_email_preview_controller"

// Invoice-specific email preview controller that extends the generic one
export default class extends GenericEmailPreviewController {
  static values = {
    ...GenericEmailPreviewController.values,
    invoiceId: Number
  }

  connect() {
    super.connect()

    // Set the URLs based on invoice ID
    this.previewUrlValue = `/invoices/${this.invoiceIdValue}/preview_email`
    this.sendUrlValue = `/invoices/${this.invoiceIdValue}/send_email`
  }
}