import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  dismiss() {
    // Add fade out animation
    this.element.style.transition = "opacity 0.15s ease-out"
    this.element.style.opacity = "0"

    // Remove element after animation completes
    setTimeout(() => {
      this.element.remove()
    }, 150)
  }
}
