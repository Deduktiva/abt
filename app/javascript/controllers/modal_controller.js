// Reusable base controller for modal dialogs (open/close + backdrop/escape dismissal)
import { Controller } from "@hotwired/stimulus"

export default class ModalController extends Controller {
  static targets = ["modal"]

  open() {
    this.modalTarget.classList.remove("d-none")
    this.modalTarget.classList.add("show")
    document.body.classList.add("modal-open")
  }

  close() {
    this.modalTarget.classList.add("d-none")
    this.modalTarget.classList.remove("show")
    document.body.classList.remove("modal-open")
  }

  // Close modal when clicking backdrop
  closeOnBackdrop(event) {
    if (event.target === this.modalTarget) {
      this.close()
    }
  }

  // Close modal on Escape key
  closeOnEscape(event) {
    if (event.key === "Escape") {
      this.close()
    }
  }
}
