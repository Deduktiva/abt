import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]

  copy(event) {
    event.preventDefault()
    if (!this.hasInputTarget) return

    const input = this.inputTarget
    input.select()
    input.setSelectionRange(0, 99999)

    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(input.value).catch(() => {
        document.execCommand("copy")
      })
    } else {
      document.execCommand("copy")
    }

    const button = event.currentTarget
    const original = button.textContent
    button.textContent = "Copied"
    if (this._resetTimeout) {
      clearTimeout(this._resetTimeout)
    }
    this._resetTimeout = setTimeout(() => {
      button.textContent = original
      this._resetTimeout = null
    }, 1500)
  }

  disconnect() {
    if (this._resetTimeout) {
      clearTimeout(this._resetTimeout)
      this._resetTimeout = null
    }
  }
}
