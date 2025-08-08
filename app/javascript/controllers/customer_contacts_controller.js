import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["contactsTable", "contactRow", "tagSuggestions"]

  connect() {
    console.log("Customer contacts controller connected")

    // Available document types for receives_* flags
    this.documentTypes = [
      { value: 'invoices', label: 'invoices' }
      // Add more document types here when needed: quotes, orders, etc.
    ]

    // Get available projects from the DOM
    this.availableProjects = this.getAvailableProjects()

    // Bind event handlers for proper cleanup
    this.boundDocumentTypeSuggestionClick = this.handleDocumentTypeSuggestionClick.bind(this)
    this.boundProjectSuggestionClick = this.handleProjectSuggestionClick.bind(this)
  }

  disconnect() {
    // Clean up any event listeners that were added dynamically
    const suggestions = this.element.querySelectorAll('.tag-suggestions .dropdown-item')
    suggestions.forEach(item => {
      item.removeEventListener('click', this.boundDocumentTypeSuggestionClick)
      item.removeEventListener('click', this.boundProjectSuggestionClick)
    })
  }

  saveContact(event) {
    event.preventDefault()
    const contactRow = event.target.closest('[data-contact-id]')
    if (!contactRow) {
      console.error('No contact row found for saveContact')
      return
    }

    const contactId = contactRow.dataset.contactId

    // Collect all field values
    const nameField = contactRow.querySelector('[data-field="name"]')
    const emailField = contactRow.querySelector('[data-field="email"]')

    if (!nameField || !emailField) {
      console.error('Could not find name or email fields')
      return
    }

    const data = {
      name: nameField.value,
      email: emailField.value
    }

    console.log('Saving contact:', contactId, 'with data:', data)

    fetch(`/customer_contacts/${contactId}`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
      },
      body: JSON.stringify({
        customer_contact: data
      })
    })
    .then(response => response.json())
    .then(data => {
      console.log('Save response:', data)
      if (data.success) {
        // Success - make a turbo_stream request to cancel and return to read mode
        const cancelUrl = `/customer_contacts/${contactId}/cancel_edit`

        fetch(cancelUrl, {
          method: 'GET',
          headers: {
            'Accept': 'text/vnd.turbo-stream.html',
            'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
          }
        })
        .then(response => response.text())
        .then(html => {
          // Apply the turbo stream response
          const tempDiv = document.createElement('div')
          tempDiv.innerHTML = html
          const turboStreamElements = tempDiv.querySelectorAll('turbo-stream')

          turboStreamElements.forEach(element => {
            Turbo.renderStreamMessage(element.outerHTML)
          })
        })
        .catch(error => {
          console.error('Error applying cancel turbo stream:', error)
          // Fallback to page reload
          window.location.reload()
        })
      } else {
        alert('Error saving contact: ' + data.errors.join(', '))
      }
    })
    .catch(error => {
      console.error('Error:', error)
      alert('Error saving contact')
    })
  }

  getAvailableProjects() {
    const customerId = this.data.get("customerId") || this.element.dataset.customerId
    const projectsData = this.element.dataset.availableProjects

    if (projectsData) {
      try {
        const projects = JSON.parse(projectsData)
        console.log('Loaded projects from data:', projects)
        return projects
      } catch (e) {
        console.error('Error parsing projects data:', e)
      }
    }

    // Fallback: extract from existing tags in the DOM
    const projects = []
    const projectTags = this.element.querySelectorAll('[data-field="projects"] .badge[data-tag]')
    projectTags.forEach(tag => {
      const id = tag.dataset.tag
      const label = tag.textContent.trim().replace('×', '').trim()
      if (id && label && !projects.find(p => p.id === id)) {
        projects.push({ id, matchcode: label, description: label, display_name: label })
      }
    })

    console.log('Fallback projects from DOM:', projects)
    return projects
  }

  addContact() {
    const customerId = this.data.get("customerId") || this.element.dataset.customerId

    fetch(`/customers/${customerId}/customer_contacts`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
      },
      body: JSON.stringify({
        customer_contact: {
          name: 'New Contact',
          email: 'contact@example.com',
          receives_invoices: false
        }
      })
    })
    .then(response => response.json())
    .then(data => {
      if (data.success) {
        // Reload the page to show the new contact
        window.location.reload()
      } else {
        alert('Error creating contact: ' + data.errors.join(', '))
      }
    })
    .catch(error => {
      console.error('Error:', error)
      alert('Error creating contact')
    })
  }

  updateField(event) {
    const contactRow = event.target.closest('[data-contact-id]')
    if (!contactRow) {
      console.error('No contact row found for updateField')
      return
    }

    const contactId = contactRow.dataset.contactId
    const field = event.target.dataset.field
    const value = event.target.type === 'checkbox' ? event.target.checked : event.target.value

    console.log('Updating field:', field, 'to value:', value, 'for contact:', contactId)

    const data = {}
    data[field] = value

    fetch(`/customer_contacts/${contactId}`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
      },
      body: JSON.stringify({
        customer_contact: data
      })
    })
    .then(response => response.json())
    .then(data => {
      console.log('Update response:', data)
      if (!data.success) {
        alert('Error updating contact: ' + data.errors.join(', '))
        // Revert the field value
        if (event.target.type === 'checkbox') {
          event.target.checked = !event.target.checked
        } else {
          event.target.value = event.target.defaultValue
        }
      }
    })
    .catch(error => {
      console.error('Error:', error)
      alert('Error updating contact')
    })
  }

  focusTagInput(event) {
    const container = event.currentTarget
    const input = container.querySelector('.tag-input-field')
    if (input) {
      input.focus()
    }
  }

  handleTagInput(event) {
    if (event.key === 'Enter' || event.key === 'Tab' || event.key === ',') {
      event.preventDefault()
      this.addTagFromInput(event)
    } else if (event.key === 'Backspace' && event.target.value === '') {
      this.removeLastTag(event)
    }
  }

  addTagFromInput(event) {
    const input = event.target
    const value = input.value.trim().toLowerCase()
    if (!value) return

    const container = input.closest('.tag-input-container')
    const field = container.dataset.field

    if (field === 'receives_flags') {
      this.addDocumentTypeTag(container, value)
    } else if (field === 'projects') {
      this.addProjectTag(container, value)
    }

    input.value = ''
    this.hideSuggestions(container)
  }

  addDocumentTypeTag(container, value) {
    const contactRow = container.closest('[data-contact-id]')
    const contactId = contactRow.dataset.contactId

    // Check if it's a valid document type
    const documentType = this.documentTypes.find(dt => dt.value === value || dt.label === value)
    if (!documentType) return

    // Check if tag already exists
    const existingTag = container.querySelector(`[data-tag="${documentType.value}"]`)
    if (existingTag) return

    // Create the tag element
    const tagInput = container.querySelector('.tag-input')
    const input = container.querySelector('.tag-input-field')

    const tagElement = document.createElement('div')
    tagElement.className = 'badge bg-primary d-flex align-items-center'
    tagElement.style.cssText = 'font-size: 0.75rem; padding: 0.25rem 0.5rem; gap: 0.25rem;'
    tagElement.dataset.tag = documentType.value
    tagElement.innerHTML = `
      ${documentType.label}
      <button type="button" class="btn-close btn-close-white" style="font-size: 0.6em; margin-left: 0.25rem;" data-action="click->customer-contacts#removeTag"></button>
    `

    tagInput.insertBefore(tagElement, input)

    // Update the backend or form fields
    if (contactId === 'new') {
      this.updateNewContactFormFields(container, 'receives_flags')
    } else {
      this.updateDocumentTypeFlags(contactId, container)
    }
  }

  addProjectTag(container, searchValue) {
    const contactRow = container.closest('[data-contact-id]')
    const contactId = contactRow.dataset.contactId

    // Find matching project
    const project = this.availableProjects.find(p =>
      p.matchcode.toLowerCase().includes(searchValue) ||
      p.display_name.toLowerCase().includes(searchValue) ||
      p.description.toLowerCase().includes(searchValue)
    )

    if (!project) return

    this.addProjectTagByObject(container, project, contactId)
  }

  addProjectTagByObject(container, project, contactId) {
    // Check if tag already exists
    const existingTag = container.querySelector(`[data-tag="${project.id}"]`)
    if (existingTag) return

    // Create the tag element
    const tagInput = container.querySelector('.tag-input')
    const input = container.querySelector('.tag-input-field')

    const tagElement = document.createElement('div')
    tagElement.className = 'badge bg-secondary d-flex align-items-center'
    tagElement.style.cssText = 'font-size: 0.75rem; padding: 0.25rem 0.5rem; gap: 0.25rem;'
    tagElement.dataset.tag = project.id
    tagElement.innerHTML = `
      ${project.display_name || project.matchcode}
      <button type="button" class="btn-close btn-close-white" style="font-size: 0.6em; margin-left: 0.25rem;" data-action="click->customer-contacts#removeTag"></button>
    `

    tagInput.insertBefore(tagElement, input)

    // Update the backend or form fields
    if (contactId === 'new') {
      this.updateNewContactFormFields(container, 'projects')
    } else {
      this.updateProjectTags(contactId, container)
    }
  }

  removeTag(event) {
    event.preventDefault()
    const tag = event.target.closest('.badge')
    const container = tag.closest('.tag-input-container')
    const contactRow = container.closest('[data-contact-id]')
    const contactId = contactRow.dataset.contactId
    const field = container.dataset.field

    tag.remove()

    if (contactId === 'new') {
      this.updateNewContactFormFields(container, field)
    } else if (field === 'receives_flags') {
      this.updateDocumentTypeFlags(contactId, container)
    } else if (field === 'projects') {
      this.updateProjectTags(contactId, container)
    }
  }

  removeLastTag(event) {
    const container = event.target.closest('.tag-input-container')
    const tags = container.querySelectorAll('.badge')
    const lastTag = tags[tags.length - 1]

    if (lastTag) {
      const removeButton = lastTag.querySelector('.btn-close')
      if (removeButton) {
        removeButton.click()
      }
    }
  }

  updateDocumentTypeFlags(contactId, container) {
    const tags = container.querySelectorAll('.badge[data-tag]')
    const flagValues = Array.from(tags).map(tag => tag.dataset.tag)

    const data = {
      receives_invoices: flagValues.includes('invoices')
      // Add more flags here when new document types are added
    }

    fetch(`/customer_contacts/${contactId}`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
      },
      body: JSON.stringify({
        customer_contact: data
      })
    })
    .then(response => response.json())
    .then(data => {
      if (!data.success) {
        alert('Error updating contact flags: ' + data.errors.join(', '))
      }
    })
    .catch(error => {
      console.error('Error:', error)
      alert('Error updating contact flags')
    })
  }

  updateProjectTags(contactId, container) {
    const tags = container.querySelectorAll('.badge[data-tag]')
    const projectIds = Array.from(tags).map(tag => parseInt(tag.dataset.tag, 10)).filter(id => !isNaN(id))

    console.log('Updating project tags for contact:', contactId, 'with project IDs:', projectIds)

    fetch(`/customer_contacts/${contactId}`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
      },
      body: JSON.stringify({
        customer_contact: {
          project_ids: projectIds
        }
      })
    })
    .then(response => response.json())
    .then(data => {
      console.log('Project update response:', data)
      if (!data.success) {
        alert('Error updating contact projects: ' + data.errors.join(', '))
      }
    })
    .catch(error => {
      console.error('Error updating project tags:', error)
      alert('Error updating contact projects')
    })
  }

  showTagSuggestions(event) {
    const input = event.target
    const container = input.closest('.tag-input-container')
    const field = container.dataset.field
    const suggestions = container.querySelector('.tag-suggestions')

    if (field === 'receives_flags') {
      this.showDocumentTypeSuggestions(container, suggestions, input.value)
    } else if (field === 'projects') {
      this.showProjectSuggestions(container, suggestions, input.value)
    }
  }

  showDocumentTypeSuggestions(container, suggestions, query = '') {
    const existingTags = Array.from(container.querySelectorAll('.badge[data-tag]')).map(tag => tag.dataset.tag)
    const availableTypes = this.documentTypes.filter(dt => !existingTags.includes(dt.value))

    const filteredTypes = query ?
      availableTypes.filter(dt => dt.label.toLowerCase().includes(query.toLowerCase())) :
      availableTypes

    suggestions.innerHTML = ''

    filteredTypes.forEach(docType => {
      const item = document.createElement('button')
      item.type = 'button'
      item.className = 'dropdown-item'
      item.textContent = docType.label
      item.addEventListener('click', this.boundDocumentTypeSuggestionClick)
      item.dataset.docTypeValue = docType.value
      item.dataset.containerId = container.dataset.field || 'receives_flags'
      suggestions.appendChild(item)
    })

    if (filteredTypes.length > 0) {
      suggestions.style.display = 'block'
    }
  }

  showProjectSuggestions(container, suggestions, query = '') {
    const existingTags = Array.from(container.querySelectorAll('.badge[data-tag]')).map(tag => tag.dataset.tag)
    const availableProjects = this.availableProjects.filter(p => !existingTags.includes(p.id.toString()))

    const filteredProjects = query ?
      availableProjects.filter(p =>
        p.matchcode.toLowerCase().includes(query.toLowerCase()) ||
        p.display_name.toLowerCase().includes(query.toLowerCase()) ||
        p.description.toLowerCase().includes(query.toLowerCase())
      ) :
      availableProjects.slice(0, 10) // Show first 10 if no query

    suggestions.innerHTML = ''

    filteredProjects.forEach(project => {
      const item = document.createElement('button')
      item.type = 'button'
      item.className = 'dropdown-item'
      item.innerHTML = `<strong>${project.matchcode}</strong> - ${project.description}`
      item.addEventListener('click', this.boundProjectSuggestionClick)
      item.dataset.projectData = JSON.stringify(project)
      suggestions.appendChild(item)
    })

    if (filteredProjects.length > 0) {
      suggestions.style.display = 'block'
    }
  }

  filterProjectSuggestions(event) {
    const input = event.target
    const container = input.closest('.tag-input-container')
    const suggestions = container.querySelector('.tag-suggestions')
    this.showProjectSuggestions(container, suggestions, input.value)
  }

  hideTagSuggestions(event) {
    const container = event.target.closest('.tag-input-container')
    // Small delay to allow click events on suggestions to fire
    setTimeout(() => {
      this.hideSuggestions(container)
    }, 150)
  }

  hideSuggestions(container) {
    const suggestions = container.querySelector('.tag-suggestions')
    if (suggestions) {
      suggestions.style.display = 'none'
    }
  }

  deleteContact(event) {
    const contactRow = event.target.closest('[data-contact-id]')
    const contactId = contactRow.dataset.contactId

    if (confirm('Are you sure you want to delete this contact?')) {
      fetch(`/customer_contacts/${contactId}`, {
        method: 'DELETE',
        headers: {
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        }
      })
      .then(response => response.json())
      .then(data => {
        if (data.success) {
          contactRow.remove()
        } else {
          alert('Error deleting contact: ' + data.errors.join(', '))
        }
      })
      .catch(error => {
        console.error('Error:', error)
        alert('Error deleting contact')
      })
    }
  }

  handleDocumentTypeSuggestionClick(e) {
    e.preventDefault()
    const item = e.currentTarget
    const docTypeValue = item.dataset.docTypeValue
    const container = item.closest('.tag-input-container')

    this.addDocumentTypeTag(container, docTypeValue)
    const input = container.querySelector('.tag-input-field')
    input.value = ''
    this.hideSuggestions(container)
    input.focus()
  }

  handleProjectSuggestionClick(e) {
    e.preventDefault()
    const item = e.currentTarget
    const project = JSON.parse(item.dataset.projectData)
    const container = item.closest('.tag-input-container')
    const contactRow = container.closest('[data-contact-id]')
    const contactId = contactRow.dataset.contactId

    console.log('Project suggestion clicked:', project)
    console.log('Contact ID:', contactId)
    this.addProjectTagByObject(container, project, contactId)
    const input = container.querySelector('.tag-input-field')
    input.value = ''
    this.hideSuggestions(container)
    input.focus()
  }

  updateNewContactFormFields(container, field) {
    // Update hidden form fields for new contact forms based on current tags
    const form = container.closest('form')
    if (!form) return

    if (field === 'receives_flags') {
      const tags = container.querySelectorAll('.badge[data-tag]')
      const flagValues = Array.from(tags).map(tag => tag.dataset.tag)

      // Update receives_invoices hidden field
      const receivesInvoicesField = form.querySelector('#new_contact_receives_invoices')
      if (receivesInvoicesField) {
        receivesInvoicesField.value = flagValues.includes('invoices')
      }
    } else if (field === 'projects') {
      const tags = container.querySelectorAll('.badge[data-tag]')
      const projectIds = Array.from(tags).map(tag => tag.dataset.tag)

      // Remove existing project_ids hidden fields
      const existingProjectFields = form.querySelectorAll('input[name*="project_ids"]')
      existingProjectFields.forEach(field => field.remove())

      // Add new project_ids hidden fields
      projectIds.forEach(projectId => {
        const hiddenField = document.createElement('input')
        hiddenField.type = 'hidden'
        hiddenField.name = 'customer_contact[project_ids][]'
        hiddenField.value = projectId
        form.appendChild(hiddenField)
      })
    }
  }
}
