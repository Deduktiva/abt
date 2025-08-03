import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "total"]

  connect() {
    this.initializeFieldVisibility()
    this.updateTotal()
  }

  initializeFieldVisibility() {
    this.containerTarget.querySelectorAll('[data-line-index]').forEach(line => {
      const typeField = line.querySelector('select[name*="[type]"]')
      if (typeField) {
        this.updateFieldVisibility(line, typeField.value)
      }
    })
  }

  addLine() {
    const template = document.querySelector('[data-invoice-lines-target="template"]')
    if (!template) return

    const newContent = template.content.cloneNode(true)

    // Replace NEW_RECORD with current timestamp to ensure uniqueness
    const timestamp = new Date().getTime()
    const html = newContent.querySelector('div').outerHTML.replace(/NEW_RECORD/g, timestamp)

    // Create a temporary container and set its HTML
    const tempDiv = document.createElement('div')
    tempDiv.innerHTML = html

    // Append the new line
    const newLine = tempDiv.firstElementChild
    this.containerTarget.appendChild(newLine)

    // Set position for the new line
    const positionField = newLine.querySelector('input[name*="[position]"]')
    if (positionField) {
      const currentLines = this.containerTarget.querySelectorAll('[data-line-index]')
      positionField.value = currentLines.length // Since we just added it, this will be the correct position
    }

    // Initialize field visibility for the new line
    const typeField = newLine.querySelector('select[name*="[type]"]')
    if (typeField) {
      this.updateFieldVisibility(newLine, typeField.value)
    }

    this.toggleProductDropdownForLine(newLine)

    this.updateTotal()
  }

  removeLine(event) {
    const line = event.target.closest('[data-line-index]')
    if (line && this.containerTarget.children.length > 1) {
      // Check if this is a persisted record (has an ID field)
      const idField = line.querySelector('input[name*="[id]"]')

      if (idField && idField.value) {
        // Mark for destruction instead of removing immediately
        const destroyField = line.querySelector('input[name*="[_destroy]"]') || this.createDestroyField(line)
        destroyField.value = '1'
        line.style.display = 'none'
      } else {
        // New record - can safely remove from DOM
        line.remove()
      }

      this.updateTotal()
    }
  }

  createDestroyField(line) {
    const idField = line.querySelector('input[name*="[id]"]')
    if (!idField) return null

    const destroyField = document.createElement('input')
    destroyField.type = 'hidden'
    destroyField.name = idField.name.replace('[id]', '[_destroy]')
    destroyField.value = '0'

    line.appendChild(destroyField)
    return destroyField
  }

  moveLineUp(event) {
    const line = event.target.closest('[data-line-index]')
    const prev = line.previousElementSibling

    if (prev) {
      line.parentNode.insertBefore(line, prev)
      this.reindexFormFields()
    }
  }

  moveLineDown(event) {
    const line = event.target.closest('[data-line-index]')
    const next = line.nextElementSibling

    if (next) {
      line.parentNode.insertBefore(next, line)
      this.reindexFormFields()
    }
  }

  reindexFormFields() {
    // Update positions based on current DOM order
    this.containerTarget.querySelectorAll('[data-line-index]').forEach((line, index) => {
      // Update the position field to reflect the new order
      const positionField = line.querySelector('input[name*="[position]"]')
      if (positionField) {
        positionField.value = index + 1 // 1-based positions
      }

      // Update all form fields within this line to use the correct index
      line.querySelectorAll('input, select, textarea').forEach(field => {
        if (field.name && field.name.includes('invoice_lines[')) {
          // Replace the index in the field name
          field.name = field.name.replace(/invoice_lines\[\d+\]/, `invoice_lines[${index}]`)
        }

        // Also update the id attribute
        if (field.id && field.id.includes('invoice_invoice_lines_attributes_')) {
          field.id = field.id.replace(/invoice_invoice_lines_attributes_\d+/, `invoice_invoice_lines_attributes_${index}`)
        }
      })

      // Update the data-line-index attribute
      line.setAttribute('data-line-index', index)
    })
  }

  fieldChanged(event) {
    // Remove error styling when user starts typing
    this.clearFieldError(event.target)
    this.updateTotal()
  }

  clearFieldError(field) {
    // Find the field_with_errors wrapper and remove error styling
    const errorWrapper = field.closest('.field_with_errors')
    if (errorWrapper) {
      // Remove the error class to clear styling
      errorWrapper.classList.remove('field_with_errors')
    }
  }

  typeChanged(event) {
    const line = event.target.closest('[data-line-index]')
    const selectedType = event.target.value

    // Remove error styling when user changes type
    this.clearFieldError(event.target)

    this.updateFieldVisibility(line, selectedType)
    this.updateTotal()
  }

  updateFieldVisibility(line, type) {
    // Hide/show fields based on type
    const notSubheadingFields = line.querySelector('[data-line-type-target="notSubheading"]')
    const itemOnlyFields = line.querySelector('div[data-line-type-target="itemOnly"]')
    const productButton = line.querySelector('button[data-line-type-target="itemOnly"]') // The "..." button

    // Show description for text, plain, and item (hide for subheading)
    notSubheadingFields.style.display = (type === 'subheading') ? 'none' : ''

    // Show rate/quantity/tax fields ONLY for items
    itemOnlyFields.style.display = (type === 'item') ? '' : 'none'

    // Show product selection button ONLY for items
    productButton.style.display = (type === 'item') ? 'inline-block' : 'none'
  }

  toggleProductDropdownForLine(line) {
    const dropdown = line.querySelector('[data-product-dropdown]')

    const isVisible = dropdown.style.display !== 'none'
    dropdown.style.display = isVisible ? 'none' : 'block'
  }

  toggleProductDropdown(event) {
    this.toggleProductDropdownForLine(event.target.closest('[data-line-index]'))
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

}
