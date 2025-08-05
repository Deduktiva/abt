import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["icon", "dropdown", "list", "badge"]
  static values = { maxErrors: Number }

  connect() {
    this.errors = []
    this.maxErrorsValue = this.maxErrorsValue || 5
    this.updateDisplay()

    // Listen for Turbo errors
    document.addEventListener('turbo:fetch-request-error', this.handleFetchError.bind(this))
    document.addEventListener('turbo:frame-missing', this.handleFrameMissing.bind(this))
    document.addEventListener('turbo:submit-end', this.handleSubmitEnd.bind(this))

    // Handle network offline/online
    window.addEventListener('offline', this.handleOffline.bind(this))
    window.addEventListener('online', this.handleOnline.bind(this))

    // Close dropdown when clicking outside
    document.addEventListener('click', this.handleOutsideClick.bind(this))
  }

  disconnect() {
    document.removeEventListener('turbo:fetch-request-error', this.handleFetchError.bind(this))
    document.removeEventListener('turbo:frame-missing', this.handleFrameMissing.bind(this))
    document.removeEventListener('turbo:submit-end', this.handleSubmitEnd.bind(this))
    window.removeEventListener('offline', this.handleOffline.bind(this))
    window.removeEventListener('online', this.handleOnline.bind(this))
    document.removeEventListener('click', this.handleOutsideClick.bind(this))
  }

  handleFetchError(event) {
    const error = {
      id: Date.now(),
      message: "Connection failed - server unreachable",
      timestamp: new Date(),
      type: "network"
    }
    this.addError(error)
  }

  handleFrameMissing(event) {
    const error = {
      id: Date.now(),
      message: "Page content missing or server error",
      timestamp: new Date(),
      type: "server"
    }
    this.addError(error)
  }

  handleSubmitEnd(event) {
    const response = event.detail.fetchResponse
    if (response && !response.succeeded) {
      const error = {
        id: Date.now(),
        message: `Form submission failed (${response.statusCode || 'Unknown error'})`,
        timestamp: new Date(),
        type: "form"
      }
      this.addError(error)
    }
  }

  handleOffline(event) {
    const error = {
      id: Date.now(),
      message: "You are now offline",
      timestamp: new Date(),
      type: "network"
    }
    this.addError(error)
  }

  handleOnline(event) {
    // Remove offline errors when coming back online
    this.errors = this.errors.filter(error => error.type !== "network" || !error.message.includes("offline"))
    this.updateDisplay()
  }

  addError(error) {
    this.errors.unshift(error)

    // Keep only the latest maxErrors
    if (this.errors.length > this.maxErrorsValue) {
      this.errors = this.errors.slice(0, this.maxErrorsValue)
    }

    this.updateDisplay()
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()

    if (this.hasDropdownTarget) {
      this.dropdownTarget.classList.toggle('show')
    }
  }

  clearAll(event) {
    event.preventDefault()
    event.stopPropagation()

    this.errors = []
    this.updateDisplay()
  }

  clearError(event) {
    event.preventDefault()
    event.stopPropagation()

    const errorId = parseInt(event.target.closest('[data-error-id]').dataset.errorId)
    this.errors = this.errors.filter(error => error.id !== errorId)
    this.updateDisplay()
  }

  close() {
    if (this.hasDropdownTarget) {
      this.dropdownTarget.classList.remove('show')
    }
  }

  handleOutsideClick(event) {
    // Close dropdown if clicking outside the error notification element
    if (!this.element.contains(event.target)) {
      this.close()
    }
  }

  preventClose(event) {
    // Prevent clicks inside dropdown from bubbling up and closing it
    event.stopPropagation()
  }

  updateDisplay() {
    const hasErrors = this.errors.length > 0

    // Show/hide entire notification item
    if (this.hasIconTarget) {
      this.iconTarget.style.display = hasErrors ? 'block' : 'none'
    }

    // Update badge count (badge is now the main element)
    if (this.hasBadgeTarget) {
      this.badgeTarget.textContent = this.errors.length
    }

    // Update error list
    if (this.hasListTarget) {
      this.listTarget.innerHTML = this.errors.map(error => `
        <li class="dropdown-item-text small py-2 px-3" data-error-id="${error.id}">
          <div class="d-flex justify-content-between align-items-start">
            <div class="flex-grow-1 me-2" style="min-width: 0;">
              <div class="fw-bold text-danger text-wrap" style="word-break: break-word;">${error.message}</div>
              <div class="text-muted small">${this.formatTimestamp(error.timestamp)}</div>
            </div>
            <button type="button" class="btn btn-sm btn-outline-secondary flex-shrink-0"
                    data-action="click->error-notification#clearError" style="min-width: 24px;">×</button>
          </div>
        </li>
      `).join('')
    }
  }

  formatTimestamp(timestamp) {
    return timestamp.toLocaleTimeString('de-DE', {
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit'
    })
  }

  // For testing purposes - can be called from console or button
  testError(event) {
    const message = event?.params?.message || "Test error"
    const error = {
      id: Date.now(),
      message: message,
      timestamp: new Date(),
      type: "test"
    }
    this.addError(error)
  }
}