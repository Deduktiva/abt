import BaseLinesController from "controllers/base_lines_controller"

export default class extends BaseLinesController {
  static targets = ["container", "total", "importError"]
  static values = { currencySymbol: String, moneyDecimalPlaces: Number, importUrl: String }

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

  // Uploads the CSV and injects the parsed lines into the open editor for review.
  async importCsv(event) {
    const input = event.target
    const file = input.files[0]
    if (!file) return

    this.clearImportError()

    try {
      const formData = new FormData()
      formData.append("file", file)

      const response = await fetch(this.importUrlValue, {
        method: "POST",
        credentials: "same-origin",
        headers: {
          "Accept": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content
        },
        body: formData
      })

      const data = await response.json().catch(() => ({}))
      if (!response.ok) {
        this.showError(data.error || `Import failed (${response.status})`)
        return
      }

      // Append, don't replace: imports add to whatever is already in the editor.
      data.lines.forEach(line => this.fillLine(this.appendLineFromTemplate({ openProductDropdown: false }), line))
      this.updateTotal()
    } catch (e) {
      this.showError(e.message)
    } finally {
      input.value = "" // allow re-selecting the same file
    }
  }

  fillLine(line, data) {
    if (!line) return

    line.querySelector('select[name*="[type]"]').value = "item"
    line.querySelector('input[name*="[title]"]').value = data.title
    line.querySelector('input[name*="[rate]"]').value = data.rate
    line.querySelector('input[name*="[quantity]"]').value = data.quantity

    const description = line.querySelector('textarea[name*="[description]"]')
    description.value = data.description

    this.updateFieldVisibility(line, "item")
    this.autoResizeTextarea(description)
    this.autoSelectSoleTaxClass(line)
  }

  // Imported lines have no tax class; when the catalogue has exactly one, pick it.
  autoSelectSoleTaxClass(line) {
    const taxClass = line.querySelector('select[name*="[sales_tax_product_class_id]"]')
    if (!taxClass) return

    const options = Array.from(taxClass.options).filter(option => option.value)
    if (options.length === 1) {
      taxClass.value = options[0].value
    }
  }

  showError(message) {
    if (!this.hasImportErrorTarget) return
    this.importErrorTarget.textContent = message
    this.importErrorTarget.classList.remove("d-none")
  }

  clearImportError() {
    if (!this.hasImportErrorTarget) return
    this.importErrorTarget.textContent = ""
    this.importErrorTarget.classList.add("d-none")
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
      dropdown.classList.add('d-none')

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
    return this.currencySymbolValue + parseFloat(amount).toFixed(this.moneyDecimalPlacesValue)
  }

  getLineType() {
    return 'invoice_lines'
  }

  getIdPrefix() {
    return 'invoice_invoice_lines_attributes_'
  }

}
