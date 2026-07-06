import { Controller } from "@hotwired/stimulus"

// Attached to a <trix-editor>'s wrapper. Trims the toolbar to the supported
// formatting subset (bold, italic, h1, bullet list, numbered list) and blocks
// attachments entirely.
export default class extends Controller {
  static REMOVE = ["link", "quote", "code", "strike", "increaseNestingLevel", "decreaseNestingLevel"]

  initialize() {
    this.trimToolbar = this.trimToolbar.bind(this)
    this.blockAttachment = this.blockAttachment.bind(this)
  }

  connect() {
    this.element.addEventListener("trix-initialize", this.trimToolbar)
    this.element.addEventListener("trix-file-accept", this.blockAttachment)
    this.element.addEventListener("trix-attachment-add", this.blockAttachment)
    // Trix may finish initializing before this controller connects, in which
    // case the trix-initialize listener above misses the event. Trim now if the
    // editor is already up.
    if (this.element.editor) this.trimToolbar({ target: this.element })
  }

  disconnect() {
    this.element.removeEventListener("trix-initialize", this.trimToolbar)
    this.element.removeEventListener("trix-file-accept", this.blockAttachment)
    this.element.removeEventListener("trix-attachment-add", this.blockAttachment)
  }

  trimToolbar(event) {
    const toolbar = event.target.toolbarElement
    if (!toolbar) return
    this.constructor.REMOVE.forEach(name => {
      toolbar.querySelectorAll(`[data-trix-attribute="${name}"], [data-trix-action="${name}"]`)
        .forEach(button => button.closest(".trix-button-group") && button.remove())
    })
    const fileTools = toolbar.querySelector(".trix-button-group--file-tools")
    if (fileTools) fileTools.remove()
  }

  blockAttachment(event) {
    event.preventDefault()
  }
}
