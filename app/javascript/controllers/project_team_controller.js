import { Controller } from "@hotwired/stimulus"

// When a bill-to customer is selected, replace the team dropdown's options
// with just the customer's team — that's the only legal choice, so showing
// the others is misleading (and `pointer-events: none` doesn't reliably
// disable a <select> in Safari). When the customer is cleared (reusable
// project), restore the full team list. Server-side `team_must_match_customer`
// enforces the rule even if JS fails or is bypassed.
export default class extends Controller {
  static targets = ["customer", "teamSelect"]

  connect() {
    this.boundChange = this.onCustomerChange.bind(this)
    if (this.hasCustomerTarget) {
      this.customerTarget.addEventListener("change", this.boundChange)
    }
    this.cacheOriginalOptions()
    this.applyLock()
  }

  disconnect() {
    if (this.hasCustomerTarget) {
      this.customerTarget.removeEventListener("change", this.boundChange)
    }
  }

  onCustomerChange() {
    this.applyLock()
  }

  cacheOriginalOptions() {
    if (!this.hasTeamSelectTarget) return
    this.originalOptions = Array.from(this.teamSelectTarget.options).map((opt) => ({
      value: opt.value,
      text: opt.textContent,
    }))
  }

  applyLock() {
    if (!this.hasCustomerTarget || !this.hasTeamSelectTarget) return

    const map = this.customerTeamMap()
    const customerId = this.customerTarget.value
    const entry = customerId ? map[customerId] : null

    if (entry && entry.team_id != null) {
      const teamId = String(entry.team_id)
      const teamName = entry.team_name || `Team ${teamId}`
      this.setOptions([{ value: teamId, text: teamName }])
      this.teamSelectTarget.value = teamId
    } else {
      this.setOptions(this.originalOptions || [])
    }
  }

  setOptions(options) {
    const current = Array.from(this.teamSelectTarget.options).map((o) => ({
      value: o.value, text: o.textContent,
    }))
    if (current.length === options.length &&
        current.every((o, i) => o.value === options[i].value && o.text === options[i].text)) {
      return
    }
    this.teamSelectTarget.innerHTML = ""
    options.forEach(({ value, text }) => {
      const opt = document.createElement("option")
      opt.value = value
      opt.textContent = text
      this.teamSelectTarget.appendChild(opt)
    })
  }

  customerTeamMap() {
    if (this._map) return this._map
    try {
      const raw = this.customerTarget.dataset.customerTeamMap
      this._map = raw ? JSON.parse(raw) : {}
    } catch (e) {
      this._map = {}
    }
    return this._map
  }
}
