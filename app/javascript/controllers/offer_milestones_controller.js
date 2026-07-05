import BaseLinesController from "controllers/base_lines_controller"

export default class extends BaseLinesController {
  static values = { currencySymbol: String, moneyDecimalPlaces: Number }

  connect() {
    super.connect()
    this.containerTarget.querySelectorAll('[data-line-index]').forEach(line => this.syncTriggerFields(line))
    this.updateTotal()
  }

  addLine() {
    const line = this.appendLineFromTemplate({ openProductDropdown: false })
    if (line) this.syncTriggerFields(line)
    this.updateTotal()
  }

  removeLine(event) {
    super.removeLine(event)
    this.updateTotal()
  }

  triggerChanged(event) {
    const line = event.target.closest('[data-line-index]')
    this.syncTriggerFields(line, { applyDefaultSkip: true })
  }

  syncTriggerFields(line, { applyDefaultSkip = false } = {}) {
    const trigger = line.querySelector('select[name*="[trigger]"]').value
    const dateWrap = line.querySelector('[data-trigger-date-wrap]')
    if (dateWrap) dateWrap.classList.toggle('d-none', trigger !== 'on_date')
    if (applyDefaultSkip) {
      const skip = line.querySelector('input[type="checkbox"][name*="[skip_delivery_note]"]')
      if (skip) skip.checked = (trigger === 'on_order')
    }
  }

  updateTotal() {
    let total = 0
    this.containerTarget.querySelectorAll('[data-line-index]').forEach(line => {
      if (line.style.display === 'none') return
      const amountField = line.querySelector('input[name*="[amount]"]')
      if (amountField) total += parseFloat(amountField.value) || 0
    })

    const totalElement = document.getElementById('offer-total-net')
    if (totalElement) totalElement.textContent = this.formatCurrency(total)
  }

  formatCurrency(amount) {
    return this.currencySymbolValue + parseFloat(amount).toFixed(this.moneyDecimalPlacesValue)
  }

  getLineType() { return 'offer_milestones' }
  getIdPrefix() { return 'offer_draft_version_attributes_milestones_attributes_' }
}
