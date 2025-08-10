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
    // Initialize auto-resize for textareas in the form
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
