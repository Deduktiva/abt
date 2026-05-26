import ModalController from "controllers/modal_controller"

// Reusable base class for email preview functionality
export default class extends ModalController {
  static targets = ["modal", "content"]
  static values = {
    previewUrl: String,     // URL to fetch preview metadata as JSON
    rawPreviewUrl: String,  // URL serving the raw email HTML for the iframe
    sendUrl: String         // URL to send email
  }

  connect() {
    this.boundFormatToggleHandler = this.handleFormatToggle.bind(this)
  }

  disconnect() {
    // Clean up any dynamically added event listeners
    const formatButtons = this.element.querySelectorAll('[data-format]')
    formatButtons.forEach(button => {
      button.removeEventListener('click', this.boundFormatToggleHandler)
    })
  }

  open(event) {
    super.open()
    this.loadContent()
  }

  async sendEmail() {
    const sendButton = this.element.querySelector('[data-action*="sendEmail"]')
    const originalText = sendButton.textContent

    // Show loading state
    sendButton.disabled = true
    sendButton.textContent = 'Sending...'

    try {
      const response = await fetch(this.sendUrlValue, {
        method: 'POST',
        headers: {
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').getAttribute('content'),
          'Accept': 'application/json'
        }
      })

      if (response.ok) {
        // Success - show feedback and close modal
        sendButton.textContent = 'Queued!'
        sendButton.classList.remove('btn-success')
        sendButton.classList.add('btn-outline-success')

        setTimeout(() => {
          this.close()
          // Optionally reload page or show success message
          window.location.reload()
        }, 1000)
      } else {
        throw new Error(`HTTP ${response.status}`)
      }
    } catch (error) {
      sendButton.textContent = 'Error - Try Again'
      sendButton.classList.remove('btn-success')
      sendButton.classList.add('btn-danger')

      setTimeout(() => {
        sendButton.textContent = originalText
        sendButton.classList.remove('btn-danger')
        sendButton.classList.add('btn-success')
        sendButton.disabled = false
      }, 3000)
    }
  }

  async loadContent() {
    // Show loading state
    this.contentTarget.innerHTML = `
      <div class="text-center">
        <div class="spinner-border" role="status">
          <span class="visually-hidden">Loading...</span>
        </div>
        <p>Loading email preview...</p>
      </div>
    `

    try {
      const response = await fetch(`${this.previewUrlValue}.json`)
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`)
      }

      const data = await response.json()

      // Build the preview HTML
      this.contentTarget.innerHTML = this.buildPreviewHTML(data)

      // Setup format toggle buttons after content is loaded
      this.setupFormatToggle()
    } catch (error) {
      this.contentTarget.innerHTML = `
        <div class="alert alert-danger">
          <h6>Error loading email preview</h6>
          <p class="mb-0">Please try again or contact support if the problem persists.</p>
        </div>
      `
    }
  }

  setupFormatToggle() {
    const formatButtons = this.contentTarget.querySelectorAll('[data-format]')

    // Remove existing listeners first to prevent duplicates
    formatButtons.forEach(button => {
      button.removeEventListener('click', this.boundFormatToggleHandler)
    })

    // Add new listeners with bound reference
    formatButtons.forEach(button => {
      button.addEventListener('click', this.boundFormatToggleHandler)
    })
  }

  handleFormatToggle(event) {
    event.preventDefault()
    const button = event.currentTarget
    const format = button.getAttribute('data-format')
    const formatButtons = this.contentTarget.querySelectorAll('[data-format]')
    const contentSections = this.contentTarget.querySelectorAll('[data-format-content]')

    // Update button states
    formatButtons.forEach(btn => btn.classList.remove('active'))
    button.classList.add('active')

    // Show/hide content sections
    contentSections.forEach(section => {
      const sectionFormat = section.getAttribute('data-format-content')
      if (sectionFormat === format) {
        section.classList.remove('d-none')
      } else {
        section.classList.add('d-none')
      }
    })
  }

  buildPreviewHTML(data) {
    const attachmentsHTML = data.attachments && data.attachments.length > 0 ? `
      <div class="row mb-2">
        <div class="col-sm-2">
          <strong>Files:</strong>
        </div>
        <div class="col-sm-10">
          ${data.attachments.map(attachment => `
            <div class="d-flex align-items-center mb-1">
              <span class="me-1">📎</span>
              <span>${attachment.filename}</span>
              <small class="text-muted ms-2">(${this.formatFileSize(attachment.size)})</small>
            </div>
          `).join('')}
        </div>
      </div>
    ` : ''

    const textToggleButton = data.text_body ? `
      <button class="btn btn-sm btn-outline-primary" data-format="text">Text</button>
    ` : ''

    const textContentSection = data.text_body ? `
      <div class="card-body email-preview-content d-none" data-format-content="text">
        <pre class="mb-0 font-monospace text-pre-wrap">${data.text_body}</pre>
      </div>
    ` : ''

    return `
      <div class="row">
        <div class="col-md-12">
          <div class="card">
            <div class="card-header d-flex justify-content-between align-items-center">
              <h5 class="mb-0">Details</h5>
              <div class="btn-group" role="group" aria-label="Format">
                <button class="btn btn-sm btn-outline-primary active" data-format="html">HTML</button>
                ${textToggleButton}
              </div>
            </div>
            <div class="card-body">
              <div class="row mb-2">
                <div class="col-sm-2">
                  <strong>To:</strong>
                </div>
                <div class="col-sm-10">
                  ${data.to || '<i>No recipient configured</i>'}
                </div>
              </div>

              <div class="row mb-2">
                <div class="col-sm-2">
                  <strong>From:</strong>
                </div>
                <div class="col-sm-10">
                  ${data.from || '<i>No sender configured</i>'}
                </div>
              </div>

              ${data.cc ? `
                <div class="row mb-2">
                  <div class="col-sm-2">
                    <strong>CC:</strong>
                  </div>
                  <div class="col-sm-10">
                    ${data.cc}
                  </div>
                </div>
              ` : ''}

              ${data.bcc ? `
                <div class="row mb-2">
                  <div class="col-sm-2">
                    <strong>BCC:</strong>
                  </div>
                  <div class="col-sm-10">
                    ${data.bcc}
                  </div>
                </div>
              ` : ''}

              <div class="row mb-2">
                <div class="col-sm-2">
                  <strong>Subject:</strong>
                </div>
                <div class="col-sm-10">
                  ${data.subject || '<i>No subject</i>'}
                </div>
              </div>

              ${attachmentsHTML}
            </div>
          </div>

          <div class="card mt-4">
            <div class="card-header">
              <h5>Content</h5>
            </div>
            <div class="card-body email-preview-content" data-format-content="html">
              ${data.has_html_body ? `
                <iframe class="email-preview-iframe" sandbox="allow-same-origin" src="${this.rawPreviewUrlValue}"></iframe>
              ` : '<p class="text-muted"><i>No HTML content available</i></p>'}
            </div>

            ${textContentSection}
          </div>
        </div>
      </div>
    `
  }

  formatFileSize(bytes) {
    if (bytes === 0) return '0 Bytes'
    const k = 1024
    const sizes = ['Bytes', 'KB', 'MB', 'GB']
    const i = Math.floor(Math.log(bytes) / Math.log(k))
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i]
  }
}
