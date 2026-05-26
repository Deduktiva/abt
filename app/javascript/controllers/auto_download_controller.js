import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["link"]

  connect() {
    if (this.hasLinkTarget) {
      this.linkTarget.click()
    }
  }
}
