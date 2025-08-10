import BaseLinesController from "controllers/base_lines_controller"

export default class extends BaseLinesController {
  static targets = ["container", "total"]

  connect() {
    super.connect()
    this.updateTotal()
  }

  addLine() {
    super.addLine()
    this.updateTotal()
  }

  removeLine(event) {
    super.removeLine(event)
    this.updateTotal()
  }


  fieldChanged(event) {
    super.fieldChanged(event)
    this.updateTotal()
  }


  typeChanged(event) {
    super.typeChanged(event)
    this.updateTotal()
  }

  updateFieldVisibility(line, type) {
    super.updateFieldVisibility(line, type)

    // Invoice-specific: Show product selection button ONLY for items
    const productButton = line.querySelector('button[data-line-type-target="itemOnly"]')
    if (productButton) {
      productButton.style.display = (type === 'item') ? 'inline-block' : 'none'
    }
  }


  useSelectedProduct(event) {
    const line = event.target.closest('[data-line-index]')
    const select = line.querySelector('[data-product-select]')
    const selectedOption = select.options[select.selectedIndex]

    if (selectedOption && selectedOption.value) {
      // Update form fields with product data
      const typeField = line.querySelector('select[name*="[type]"]')
      const titleField = line.querySelector('input[name*="[title]"]')
      const descriptionField = line.querySelector('textarea[name*="[description]"]')
      const rateField = line.querySelector('input[name*="[rate]"]')
      const taxClassField = line.querySelector('select[name*="[sales_tax_product_class_id]"]')

      // Switch to item type when product is selected
      typeField.value = 'item'
      titleField.value = selectedOption.dataset.title || ''
      descriptionField.value = selectedOption.dataset.description || ''
      rateField.value = selectedOption.dataset.rate || ''
      taxClassField.value = selectedOption.dataset.taxClass || ''

      // Hide the dropdown
      const dropdown = line.querySelector('[data-product-dropdown]')
      dropdown.style.display = 'none'

      // Update totals
      this.updateTotal()
    }
  }

  updateTotal() {
    let total = 0

    this.containerTarget.querySelectorAll('[data-line-index]:not([style*="display: none"])').forEach(line => {
      // Only calculate totals for lines that are actually type 'item'
      const typeField = line.querySelector('select[name*="[type]"]')
      const lineType = typeField ? typeField.value : null

      if (lineType === 'item') {
        const quantityField = line.querySelector('input[name*="[quantity]"]')
        const rateField = line.querySelector('input[name*="[rate]"]')

        if (quantityField && rateField) {
          const quantity = parseFloat(quantityField.value) || 0
          const rate = parseFloat(rateField.value) || 0
          const lineTotal = quantity * rate

          // Update line total display
          const lineTotalElement = line.querySelector('[data-line-total]')
          lineTotalElement.textContent = this.formatCurrency(lineTotal)

          total += lineTotal
        }
      } else {
        // Clear the line total display for non-item types
        const lineTotalElement = line.querySelector('[data-line-total]')
        if (lineTotalElement) {
          lineTotalElement.textContent = this.formatCurrency(0)
        }
      }
    })

    this.totalTarget.textContent = this.formatCurrency(total)
  }

  formatCurrency(amount) {
    // Get currency from a data attribute or default to EUR
    const currency = document.querySelector('[data-currency]')?.getAttribute('data-currency') || 'EUR'
    const formatted = parseFloat(amount).toFixed(2)

    switch(currency) {
      case 'EUR':
        return '€' + formatted
      case 'USD':
        return '$' + formatted
      case 'GBP':
        return '£' + formatted
      default:
        return currency + ' ' + formatted
    }
  }

  getLineType() {
    return 'invoice_lines'
  }

  getIdPrefix() {
    return 'invoice_invoice_lines_attributes_'
  }

}
