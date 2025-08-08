import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["select", "search", "dropdown", "customerField"]
  static values = {
    currentCustomerId: Number,
    currentProjectId: Number
  }

  connect() {
    this.boundDocumentClickHandler = this.handleDocumentClick.bind(this)
    this.boundCustomerChangedHandler = this.customerChanged.bind(this)


    // Only load projects if we have a customer selected
    if (this.currentCustomerIdValue) {
      this.loadProjects()
    } else {
      this.showSelectCustomerMessage()
    }

    this.setupEventListeners()
  }

  disconnect() {
    // Remove document event listener
    document.removeEventListener('click', this.boundDocumentClickHandler)

    // Remove customer field event listeners
    if (this.hasCustomerFieldTarget) {
      this.customerFieldTarget.removeEventListener('blur', this.boundCustomerChangedHandler)
      this.customerFieldTarget.removeEventListener('change', this.boundCustomerChangedHandler)
      this.customerFieldTarget.removeEventListener('input', this.boundCustomerChangedHandler)
    }
  }

  setupEventListeners() {
    // Listen for customer field changes
    if (this.hasCustomerFieldTarget) {
      this.customerFieldTarget.addEventListener('blur', this.boundCustomerChangedHandler)
      this.customerFieldTarget.addEventListener('change', this.boundCustomerChangedHandler)
      this.customerFieldTarget.addEventListener('input', this.boundCustomerChangedHandler)
    }

    // Setup search functionality
    if (this.hasSearchTarget) {
      this.searchTarget.addEventListener('input', this.filterOptions.bind(this))
      this.searchTarget.addEventListener('keydown', this.handleKeyNavigation.bind(this))
    }

    // Setup dropdown toggle
    this.selectTarget.addEventListener('click', this.toggleDropdown.bind(this))

    // Close dropdown when clicking outside
    document.addEventListener('click', this.boundDocumentClickHandler)
  }

  handleDocumentClick(event) {
    if (!this.element.contains(event.target)) {
      this.closeDropdown()
    }
  }

  async customerChanged(event) {
    const newCustomerId = event.target.value
    const oldCustomerId = this.currentCustomerIdValue

    if (newCustomerId !== oldCustomerId.toString()) {
      this.currentCustomerIdValue = newCustomerId ? parseInt(newCustomerId) : null

      if (this.currentCustomerIdValue) {
        await this.loadProjects()
      } else {
        // No customer selected - clear projects and show message
        this.clearSelection()
        this.showSelectCustomerMessage()
      }
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

      const url = `/projects?${params}`

      const response = await fetch(url, {
        method: 'GET',
        headers: {
          'Accept': 'text/vnd.turbo-stream.html',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })

      if (response.ok) {
        const turboStreamHtml = await response.text()

        // Use MutationObserver to watch for DOM changes
        this.observeDropdownChanges(() => {
          this.attachOptionEventListeners()
          this.reattachSearchListener()
          this.validateCurrentProject()
          this.hideLoading()
        })

        Turbo.renderStreamMessage(turboStreamHtml)
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
      // Remove any existing listeners by cloning the node
      const newOption = option.cloneNode(true)
      option.parentNode.replaceChild(newOption, option)

      const projectId = parseInt(newOption.dataset.projectId)
      const projectName = newOption.querySelector('.fw-normal').textContent
      const projectMatchcode = newOption.querySelector('.small').textContent.trim()

      newOption.addEventListener('click', () => {
        this.selectProject({
          id: projectId,
          name: projectName,
          matchcode: projectMatchcode
        })
      })
    })
  }

  reattachSearchListener() {
    // Re-attach search functionality after Turbo Stream update
    if (this.hasSearchTarget) {
      const searchInput = this.searchTarget
      if (searchInput) {
        // Remove existing listeners by replacing with clone
        const newSearchInput = searchInput.cloneNode(true)
        searchInput.parentNode.replaceChild(newSearchInput, searchInput)

        // Re-attach event listeners
        newSearchInput.addEventListener('input', this.filterOptions.bind(this))
        newSearchInput.addEventListener('keydown', this.handleKeyNavigation.bind(this))
      }
    }
  }

  observeDropdownChanges(callback) {
    const observer = new MutationObserver((mutations) => {
      // Check if project options were added/changed
      const hasProjectOptions = mutations.some(mutation =>
        Array.from(mutation.addedNodes).some(node =>
          node.nodeType === Node.ELEMENT_NODE &&
          (node.classList?.contains('project-option') ||
           node.querySelector?.('.project-option'))
        )
      )

      if (hasProjectOptions) {
        observer.disconnect()
        callback()
      }
    })

    // Observe changes to the dropdown target
    observer.observe(this.dropdownTarget, {
      childList: true,
      subtree: true
    })
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

    // Check if the current project exists in the DOM (after Turbo Stream update)
    const validProjectElement = this.dropdownTarget.querySelector(`[data-project-id="${this.currentProjectIdValue}"]`)

    if (!validProjectElement) {
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

  showSelectCustomerMessage() {
    const display = this.selectTarget.querySelector('.select-display')
    if (display) {
      display.innerHTML = '<span class="text-muted">Select customer first...</span>'
    }

    // Also update the dropdown content
    const dropdownContent = this.dropdownTarget.querySelector('.dropdown-content')
    if (dropdownContent) {
      dropdownContent.innerHTML = '<div class="dropdown-item text-muted">Select a customer first</div>'
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
