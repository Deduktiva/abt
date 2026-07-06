import { Controller } from "@hotwired/stimulus"

// Shows the panel only while the observed input has a value.
export default class extends Controller {
  static targets = ["input", "panel"]

  connect() {
    this.sync()
  }

  sync() {
    this.panelTarget.classList.toggle("d-none", this.inputTarget.value.trim() === "")
  }
}
