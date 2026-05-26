import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["select"]

  connect() {
    this.collapse()
  }

  expand() {
    this.swap("full")
  }

  collapse() {
    this.swap("short")
  }

  submit() {
    this.collapse()
    this.element.closest("form").requestSubmit()
  }

  swap(key) {
    this.selectTarget.querySelectorAll("option").forEach((opt) => {
      const value = opt.dataset[key]
      if (value !== undefined) opt.text = value
    })
  }
}
