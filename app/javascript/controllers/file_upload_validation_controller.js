import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["fileInput", "submitButton"]

  connect() {
    this.boundClickHandler = this.handleSubmitClick.bind(this)
    this.submitButtonTarget.addEventListener('click', this.boundClickHandler)
  }

  disconnect() {
    if (this.boundClickHandler) {
      this.submitButtonTarget.removeEventListener('click', this.boundClickHandler)
    }
  }

  handleSubmitClick(event) {
    if (!this.fileInputTarget.files || this.fileInputTarget.files.length === 0) {
      event.preventDefault()
      this.fileInputTarget.click()
    }
  }
}
