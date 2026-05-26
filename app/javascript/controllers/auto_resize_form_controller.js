import { Controller } from "@hotwired/stimulus"
import { AutoResizeTextareaMixin } from "mixins/auto_resize_textarea_mixin"

// Wires the auto-resize-textarea mixin to every textarea inside the form.
// Used by both invoice and delivery-note edit/new forms — neither has any
// form-specific behaviour beyond the auto-resize.
export default class extends Controller {
  // Include auto-resize textarea mixin methods
  initializeAutoResizeTextareas = AutoResizeTextareaMixin.initializeAutoResizeTextareas
  autoResizeTextarea = AutoResizeTextareaMixin.autoResizeTextarea
  cleanupAutoResizeTextareas = AutoResizeTextareaMixin.cleanupAutoResizeTextareas
  handleTextareaFieldChanged = AutoResizeTextareaMixin.handleTextareaFieldChanged

  connect() {
    this.initializeAutoResizeTextareas(this.element)
  }

  fieldChanged(event) {
    // Auto-resize textarea if needed
    this.handleTextareaFieldChanged(event)
  }

  disconnect() {
    this.cleanupAutoResizeTextareas(this.element)
  }
}
