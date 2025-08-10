import { Controller } from "@hotwired/stimulus"
import { AutoResizeTextareaMixin } from "../mixins/auto_resize_textarea_mixin"

export default class extends Controller {
  static targets = ["container"]

  // Include auto-resize textarea mixin methods
  initializeAutoResizeTextareas = AutoResizeTextareaMixin.initializeAutoResizeTextareas
  autoResizeTextarea = AutoResizeTextareaMixin.autoResizeTextarea
  cleanupAutoResizeTextareas = AutoResizeTextareaMixin.cleanupAutoResizeTextareas
  handleTextareaFieldChanged = AutoResizeTextareaMixin.handleTextareaFieldChanged

  connect() {
    this.initializeFieldVisibility()
    this.initializeAutoResizeTextareas()
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
    const template = document.querySelector(`[data-${this.getLineType()}-target="template"]`)
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
    this.initializeAutoResizeTextareas(newLine)
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
        const lineType = this.getLineType()
        if (field.name && field.name.includes(`${lineType}[`)) {
          // Replace the index in the field name
          field.name = field.name.replace(new RegExp(`${lineType}\\[\\d+\\]`), `${lineType}[${index}]`)
        }

        // Also update the id attribute
        const idPrefix = this.getIdPrefix()
        if (field.id && field.id.includes(idPrefix)) {
          field.id = field.id.replace(new RegExp(`${idPrefix}\\d+`), `${idPrefix}${index}`)
        }
      })

      // Update the data-line-index attribute
      line.setAttribute('data-line-index', index)
    })
  }

  fieldChanged(event) {
    // Remove error styling when user starts typing
    this.clearFieldError(event.target)

    // Auto-resize textarea if needed
    this.handleTextareaFieldChanged(event)
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
  }

  updateFieldVisibility(line, type) {
    // Hide/show fields based on type
    const notSubheadingFields = line.querySelector('[data-line-type-target="notSubheading"]')
    const itemOnlyFields = line.querySelector('div[data-line-type-target="itemOnly"]')

    // Show description for text, plain, and item (hide for subheading)
    notSubheadingFields.style.display = (type === 'subheading') ? 'none' : ''

    // Show rate/quantity/tax fields ONLY for items
    itemOnlyFields.style.display = (type === 'item') ? '' : 'none'
  }

  toggleProductDropdownForLine(line) {
    const dropdown = line.querySelector('[data-product-dropdown]')

    const isVisible = dropdown.style.display !== 'none'
    dropdown.style.display = isVisible ? 'none' : 'block'
  }

  toggleProductDropdown(event) {
    this.toggleProductDropdownForLine(event.target.closest('[data-line-index]'))
  }

  disconnect() {
    this.cleanupAutoResizeTextareas()
  }

  // Abstract methods to be implemented by subclasses
  getLineType() {
    throw new Error('getLineType() must be implemented by subclass')
  }

  getIdPrefix() {
    throw new Error('getIdPrefix() must be implemented by subclass')
  }
}
