import { Controller } from "@hotwired/stimulus"

// Reusable base class for email preview functionality
export default class extends Controller {
  static targets = ["modal", "content"]
  static values = {
    previewUrl: String,  // URL to fetch preview data
    sendUrl: String      // URL to send email
  }

  connect() {
  }

  open(event) {
    this.modalTarget.classList.remove('d-none')
    this.modalTarget.classList.add('show')
    document.body.classList.add('modal-open')

    // Load content
    this.loadContent()
  }

  close() {
    this.modalTarget.classList.add('d-none')
    this.modalTarget.classList.remove('show')
    document.body.classList.remove('modal-open')
  }

  // Close modal when clicking backdrop
  closeOnBackdrop(event) {
    if (event.target === this.modalTarget) {
      this.close()
    }
  }

  // Close modal on Escape key
  closeOnEscape(event) {
    if (event.key === 'Escape') {
      this.close()
    }
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
        sendButton.textContent = 'Sent!'
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
    const contentSections = this.contentTarget.querySelectorAll('[data-format-content]')

    formatButtons.forEach(button => {
      button.addEventListener('click', (event) => {
        event.preventDefault()
        const format = button.getAttribute('data-format')

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
      })
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
        <pre class="mb-0" style="white-space: pre-wrap; font-family: monospace;">${data.text_body}</pre>
      </div>
    ` : ''

    // Create isolated iframe content
    const iframeContent = data.html_body ? `data:text/html;charset=utf-8,${encodeURIComponent(data.html_body)}` : ''

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
              ${data.html_body ? `
                <iframe src="${iframeContent}" style="width: 100%; height: 400px; border: 1px solid #dee2e6; border-radius: 0.375rem;"></iframe>
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