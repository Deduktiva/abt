import { Controller } from "@hotwired/stimulus"

// Much simpler controller that lets Turbo handle most of the work
export default class extends Controller {
  connect() {
    console.log("Contact form controller connected")
  }

  submitForm(event) {
    // Auto-submit form on field changes (name/email)
    const form = event.target.closest("form")
    if (form) {
      form.requestSubmit()
    }
  }

  toggleDocumentType(event) {
    event.preventDefault()
    const documentType = event.target.dataset.documentType
    const form = event.target.closest("form")
    const hiddenField = form.querySelector(`input[name="customer_contact[receives_${documentType}]"]`)

    if (hiddenField) {
      // Toggle the value
      hiddenField.value = hiddenField.value === "true" ? "false" : "true"
      form.requestSubmit()
    }
  }

  addProject(event) {
    event.preventDefault()
    const projectId = event.target.dataset.projectId
    const form = event.target.closest("form")

    // Add hidden field for this project
    const hiddenField = document.createElement("input")
    hiddenField.type = "hidden"
    hiddenField.name = "customer_contact[project_ids][]"
    hiddenField.value = projectId
    hiddenField.dataset.projectId = projectId

    form.appendChild(hiddenField)
    form.requestSubmit()
  }

  removeProject(event) {
    event.preventDefault()
    const projectId = event.target.dataset.projectId
    const form = event.target.closest("form")

    // Remove hidden field for this project
    const hiddenField = form.querySelector(`input[data-project-id="${projectId}"]`)
    if (hiddenField) {
      hiddenField.remove()
      form.requestSubmit()
    }
  }

  cancelNew(event) {
    event.preventDefault()
    // Just reload the table without the new form
    const form = event.target.closest("form")
    const customerId = form.action.match(/customers\/(\d+)/)[1]

    // Use Turbo.visit to reload the contacts table without new form
    const customerContactsFrame = document.getElementById(`customer_contacts_${customerId}`)
    if (customerContactsFrame) {
      customerContactsFrame.src = `/customers/${customerId}/customer_contacts/cancel_new`
    }
  }
}