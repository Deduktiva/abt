import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu", "toggle"]

  connect() {
    // Close menu when clicking outside
    document.addEventListener('click', this.closeOnOutsideClick.bind(this))
  }

  disconnect() {
    document.removeEventListener('click', this.closeOnOutsideClick.bind(this))
  }

  toggle() {
    if (this.hasMenuTarget) {
      this.menuTarget.classList.toggle('show')

      // Update toggle button aria-expanded
      if (this.hasToggleTarget) {
        const isExpanded = this.menuTarget.classList.contains('show')
        this.toggleTarget.setAttribute('aria-expanded', isExpanded)
      }
    }
  }

  close() {
    if (this.hasMenuTarget) {
      this.menuTarget.classList.remove('show')

      if (this.hasToggleTarget) {
        this.toggleTarget.setAttribute('aria-expanded', 'false')
      }
    }
  }

  closeOnOutsideClick(event) {
    if (!this.element.contains(event.target)) {
      this.close()
    }
  }
}