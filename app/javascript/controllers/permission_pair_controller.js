import { Controller } from "@hotwired/stimulus"

// Pairs every <foo>.view / <foo>.edit checkbox so that:
//  - ticking .edit auto-ticks the matching .view (no .edit without .view)
//  - unticking .view auto-unticks the matching .edit (same reason)
// The server treats each permission key independently — without this an
// admin could assign customers.edit alone, and the user would 403 on the
// index page they need to reach to use the edit action.
//
// Discovery is by id convention: perm_<scope>_view / perm_<scope>_edit
// (the same id pattern the form uses for label `for=` linking).
export default class extends Controller {
  connect() {
    this.boundOnChange = this.onChange.bind(this)
    this.element.addEventListener("change", this.boundOnChange)
  }

  disconnect() {
    this.element.removeEventListener("change", this.boundOnChange)
  }

  onChange(event) {
    const cb = event.target
    if (!(cb instanceof HTMLInputElement) || cb.type !== "checkbox" || !cb.id) return

    const editMatch = cb.id.match(/^perm_(.+)_edit$/)
    if (editMatch && cb.checked) {
      const view = this.element.querySelector(`#perm_${editMatch[1]}_view`)
      if (view && !view.checked) view.checked = true
      return
    }

    const viewMatch = cb.id.match(/^perm_(.+)_view$/)
    if (viewMatch && !cb.checked) {
      const edit = this.element.querySelector(`#perm_${viewMatch[1]}_edit`)
      if (edit && edit.checked) edit.checked = false
    }
  }
}
