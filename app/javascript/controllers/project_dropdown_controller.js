import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["select", "search", "dropdown", "option", "customerField"]
  static values = {
    currentCustomerId: Number,
    currentProjectId: Number
  }

  connect() {
    this.loadProjects()
    this.setupEventListeners()
  }

  setupEventListeners() {
    // Listen for customer field changes
    if (this.hasCustomerFieldTarget) {
      this.customerFieldTarget.addEventListener('blur', this.customerChanged.bind(this))
      this.customerFieldTarget.addEventListener('change', this.customerChanged.bind(this))
    }

    // Setup search functionality
    if (this.hasSearchTarget) {
      this.searchTarget.addEventListener('input', this.filterOptions.bind(this))
      this.searchTarget.addEventListener('keydown', this.handleKeyNavigation.bind(this))
    }

    // Setup dropdown toggle
    this.selectTarget.addEventListener('click', this.toggleDropdown.bind(this))

    // Close dropdown when clicking outside
    document.addEventListener('click', (event) => {
      if (!this.element.contains(event.target)) {
        this.closeDropdown()
      }
    })
  }

  async customerChanged(event) {
    const newCustomerId = event.target.value
    const oldCustomerId = this.currentCustomerIdValue

    if (newCustomerId !== oldCustomerId.toString()) {
      this.currentCustomerIdValue = newCustomerId ? parseInt(newCustomerId) : null
      await this.loadProjects()
      this.validateCurrentProject()
    }
  }

  async loadProjects() {
    try {
      // Store current display before potentially showing loading
      this.storeCurrentDisplay()

      // Only show loading if we don't have a valid project display
      if (!this.hasValidProjectDisplay()) {
        this.showLoading()
      }

      const params = new URLSearchParams()
      if (this.currentCustomerIdValue) {
        params.append('customer_id', this.currentCustomerIdValue)
      }
      params.append('include_reusable', 'true')
      params.append('filter', 'active')

      const response = await fetch(`/projects?${params}`, {
        method: 'GET',
        headers: {
          'Accept': 'text/vnd.turbo-stream.html',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })

      if (response.ok) {
        const turboStreamHtml = await response.text()
        Turbo.renderStreamMessage(turboStreamHtml)

        // Wait for DOM update, then re-attach event listeners and restore selection
        setTimeout(() => {
          this.attachOptionEventListeners()
          this.hideLoading()
        }, 10)
      } else {
        this.handleError(`Failed to load projects: ${response.statusText}`)
        this.restoreDisplayOrShowError()
      }
    } catch (error) {
      this.handleError(`Error loading projects: ${error.message}`)
      this.restoreDisplayOrShowError()
    }
  }

  handleError(message) {
    // Dispatch a custom event to trigger the error notification system
    const errorEvent = new CustomEvent('turbo:fetch-request-error', {
      detail: {
        response: {
          statusCode: 500,
          statusText: message
        }
      }
    })
    document.dispatchEvent(errorEvent)
  }

  attachOptionEventListeners() {
    // Re-attach click listeners to project options after Turbo Stream update
    const options = this.dropdownTarget.querySelectorAll('.project-option')
    options.forEach(option => {
      const projectId = parseInt(option.dataset.projectId)
      const projectName = option.querySelector('.fw-normal').textContent
      const projectMatchcode = option.querySelector('.small').textContent.trim()

      option.addEventListener('click', () => {
        this.selectProject({
          id: projectId,
          name: projectName,
          matchcode: projectMatchcode
        })
      })
    })
  }

  renderOptions() {
    // This method is no longer needed since we use Turbo Streams
    // but keeping it for backward compatibility during transition
    const dropdownContent = this.dropdownTarget.querySelector('.dropdown-content')
    if (!dropdownContent) return

    dropdownContent.innerHTML = ''

    if (this.projects.length === 0) {
      dropdownContent.innerHTML = '<div class="dropdown-item text-muted">No projects available</div>'
      return
    }

    this.projects.forEach(project => {
      const option = this.createOptionElement(project)
      dropdownContent.appendChild(option)
    })
  }

  createOptionElement(project) {
    const option = document.createElement('div')
    option.className = 'dropdown-item project-option'
    option.dataset.projectId = project.id
    option.dataset.projectName = project.name.toLowerCase()
    option.dataset.projectMatchcode = project.matchcode.toLowerCase()

    const nameDiv = document.createElement('div')
    nameDiv.className = 'fw-normal'
    nameDiv.textContent = project.name

    const detailDiv = document.createElement('div')
    detailDiv.className = 'small text-muted d-flex justify-content-between align-items-center'

    const matchcodeSpan = document.createElement('span')
    matchcodeSpan.textContent = project.matchcode
    detailDiv.appendChild(matchcodeSpan)

    if (project.is_reusable) {
      const reusableIcon = document.createElement('span')
      reusableIcon.className = 'text-success'
      reusableIcon.title = 'Reusable project'
      reusableIcon.textContent = '♻️'
      detailDiv.appendChild(reusableIcon)
    }

    option.appendChild(nameDiv)
    option.appendChild(detailDiv)

    option.addEventListener('click', () => this.selectProject(project))

    return option
  }

  selectProject(project) {
    this.currentProjectIdValue = project.id
    this.updateSelectDisplay(project)
    this.closeDropdown()

    // Update the actual form field
    const hiddenInput = this.element.querySelector('input[name*="[project_id]"]')
    if (hiddenInput) {
      hiddenInput.value = project.id
    }

    // Clear any validation errors
    this.markAsValid()
  }

  updateSelectDisplay(project) {
    const display = this.selectTarget.querySelector('.select-display')
    if (display) {
      display.innerHTML = `
        <div class="fw-normal">${project.name}</div>
        <div class="small text-muted">${project.matchcode}</div>
      `
    }
  }

  validateCurrentProject() {
    if (!this.currentProjectIdValue) return

    const validProject = this.projects.find(p => p.id === this.currentProjectIdValue)

    if (!validProject) {
      // Clear invalid project
      this.currentProjectIdValue = null
      this.clearSelection()
      this.markAsInvalid()
    } else {
      this.markAsValid()
    }
  }

  clearSelection() {
    const display = this.selectTarget.querySelector('.select-display')
    if (display) {
      display.innerHTML = '<span class="text-muted">Select project...</span>'
    }

    const hiddenInput = this.element.querySelector('input[name*="[project_id]"]')
    if (hiddenInput) {
      hiddenInput.value = ''
    }
  }

  markAsInvalid() {
    this.selectTarget.classList.add('is-invalid')
  }

  markAsValid() {
    this.selectTarget.classList.remove('is-invalid')
  }

  toggleDropdown() {
    if (this.dropdownTarget.classList.contains('show')) {
      this.closeDropdown()
    } else {
      this.openDropdown()
    }
  }

  openDropdown() {
    this.dropdownTarget.classList.add('show')
    if (this.hasSearchTarget) {
      this.searchTarget.focus()
    }
  }

  closeDropdown() {
    this.dropdownTarget.classList.remove('show')
    if (this.hasSearchTarget) {
      this.searchTarget.value = ''
    }
    this.filterOptions()
  }

  filterOptions() {
    const searchTerm = this.hasSearchTarget ? this.searchTarget.value.toLowerCase() : ''
    const options = this.dropdownTarget.querySelectorAll('.project-option')

    options.forEach(option => {
      const name = option.dataset.projectName
      const matchcode = option.dataset.projectMatchcode

      if (name.includes(searchTerm) || matchcode.includes(searchTerm)) {
        option.style.display = 'block'
      } else {
        option.style.display = 'none'
      }
    })
  }

  handleKeyNavigation(event) {
    const visibleOptions = Array.from(this.dropdownTarget.querySelectorAll('.project-option'))
      .filter(option => option.style.display !== 'none')

    if (visibleOptions.length === 0) return

    if (event.key === 'ArrowDown') {
      event.preventDefault()
      this.navigateOptions(visibleOptions, 1)
    } else if (event.key === 'ArrowUp') {
      event.preventDefault()
      this.navigateOptions(visibleOptions, -1)
    } else if (event.key === 'Enter') {
      event.preventDefault()
      const focused = this.dropdownTarget.querySelector('.project-option.focus')
      if (focused) {
        focused.click()
      }
    } else if (event.key === 'Escape') {
      this.closeDropdown()
    }
  }

  navigateOptions(options, direction) {
    const currentFocused = this.dropdownTarget.querySelector('.project-option.focus')
    let newIndex = 0

    if (currentFocused) {
      currentFocused.classList.remove('focus')
      const currentIndex = options.indexOf(currentFocused)
      newIndex = (currentIndex + direction + options.length) % options.length
    }

    options[newIndex].classList.add('focus')
    options[newIndex].scrollIntoView({ block: 'nearest' })
  }

  storeCurrentDisplay() {
    const display = this.selectTarget.querySelector('.select-display')
    if (display) {
      this.storedDisplayHTML = display.innerHTML
    }
  }

  hasValidProjectDisplay() {
    const display = this.selectTarget.querySelector('.select-display')
    if (!display) return false

    const html = display.innerHTML
    return html &&
           !html.includes('Loading...') &&
           !html.includes('Select project...') &&
           html.includes('fw-normal') &&
           this.currentProjectIdValue  // Must also have a valid project ID
  }

  restoreDisplayOrShowError() {
    const display = this.selectTarget.querySelector('.select-display')
    if (display && this.storedDisplayHTML) {
      // Restore the previous display
      display.innerHTML = this.storedDisplayHTML
    } else {
      // Show error state
      this.clearSelection()
      this.markAsInvalid()
    }
  }

  showLoading() {
    const display = this.selectTarget.querySelector('.select-display')
    if (display) {
      display.innerHTML = '<span class="text-muted">Loading...</span>'
    }
  }

  hideLoading() {
    // Restore the project display if one is already selected
    if (this.currentProjectIdValue) {
      const display = this.selectTarget.querySelector('.select-display')
      if (display) {
        // Find the selected project in the new options
        const selectedOption = this.dropdownTarget.querySelector(`[data-project-id="${this.currentProjectIdValue}"]`)

        if (selectedOption) {
          const name = selectedOption.querySelector('.fw-normal').textContent
          const matchcodeElement = selectedOption.querySelector('.small span')
          const matchcode = matchcodeElement ? matchcodeElement.textContent.trim() : ''

          display.innerHTML = `
            <div class="fw-normal">${name}</div>
            <div class="small text-muted">${matchcode}</div>
          `
          this.markAsValid()
        } else {
          // Project not found in new options - try to restore from stored display
          if (this.storedDisplayHTML && this.storedDisplayHTML.includes('fw-normal')) {
            display.innerHTML = this.storedDisplayHTML
            this.markAsValid()
          } else {
            // Project is no longer valid
            this.clearSelection()
            this.markAsInvalid()
          }
        }
      }
    } else {
      const display = this.selectTarget.querySelector('.select-display')
      if (display && display.innerHTML.includes('Loading')) {
        display.innerHTML = '<span class="text-muted">Select project...</span>'
      }
    }
  }
}