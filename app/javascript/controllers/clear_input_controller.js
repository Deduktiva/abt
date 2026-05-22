import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["field"]

  clear(event) {
    event.preventDefault()
    if (this.hasFieldTarget) {
      this.fieldTarget.value = ""
      this.fieldTarget.dispatchEvent(new Event("input", { bubbles: true }))
      this.fieldTarget.dispatchEvent(new Event("change", { bubbles: true }))
    }
  }
}
