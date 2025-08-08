import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["selectAll", "checkbox", "submitButton"]

  connect() {
    this.updateButton()
  }

  toggleAll(event) {
    this.checkboxTargets.forEach(checkbox => {
      checkbox.checked = event.target.checked
    })
    this.updateButton()
  }

  updateButton() {
    const checkedBoxes = this.checkboxTargets.filter(checkbox => checkbox.checked)

    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = checkedBoxes.length === 0
    }
  }
}
