import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu", "toggle"]

  connect() {
    // Close menu when clicking outside
    this.boundCloseOnOutsideClick = this.closeOnOutsideClick.bind(this)
    document.addEventListener('click', this.boundCloseOnOutsideClick)
  }

  disconnect() {
    document.removeEventListener('click', this.boundCloseOnOutsideClick)
  }

  toggle(event) {
    event.preventDefault()

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