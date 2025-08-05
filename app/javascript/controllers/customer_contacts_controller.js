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
    const contactId = contactRow.dataset.contactId
    const field = event.target.dataset.field
    const value = event.target.type === 'checkbox' ? event.target.checked : event.target.value

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
    tagElement.className = 'badge bg-primary d-flex align-items-center gap-1'
    tagElement.dataset.tag = documentType.value
    tagElement.innerHTML = `
      ${documentType.label}
      <button type="button" class="btn-close btn-close-white ms-1" style="font-size: 0.6em;" data-action="click->customer-contacts#removeTag"></button>
    `

    tagInput.insertBefore(tagElement, input)

    // Update the backend
    this.updateDocumentTypeFlags(contactId, container)
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

    // Update the backend
    this.updateProjectTags(contactId, container)
  }

  removeTag(event) {
    event.preventDefault()
    const tag = event.target.closest('.badge')
    const container = tag.closest('.tag-input-container')
    const contactRow = container.closest('[data-contact-id]')
    const contactId = contactRow.dataset.contactId
    const field = container.dataset.field

    tag.remove()

    if (field === 'receives_flags') {
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
    const projectIds = Array.from(tags).map(tag => tag.dataset.tag)

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
      if (!data.success) {
        alert('Error updating contact projects: ' + data.errors.join(', '))
      }
    })
    .catch(error => {
      console.error('Error:', error)
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
      item.addEventListener('click', (e) => {
        e.preventDefault()
        this.addDocumentTypeTag(container, docType.value)
        const input = container.querySelector('.tag-input-field')
        input.value = ''
        this.hideSuggestions(container)
        input.focus()
      })
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
      item.addEventListener('click', (e) => {
        e.preventDefault()
        console.log('Project suggestion clicked:', project)
        const contactRow = container.closest('[data-contact-id]')
        const contactId = contactRow.dataset.contactId
        console.log('Contact ID:', contactId)
        this.addProjectTagByObject(container, project, contactId)
        const input = container.querySelector('.tag-input-field')
        input.value = ''
        this.hideSuggestions(container)
        input.focus()
      })
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
}