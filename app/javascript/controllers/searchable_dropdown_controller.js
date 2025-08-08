import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["select", "search", "dropdown", "dependentField"]
  static values = {
    currentDependentId: Number,
    currentItemId: Number,
    url: String,
    dependentParam: String,
    itemName: String,
    itemIdParam: String,
    selectPrompt: String,
    dependentSelectPrompt: String,
    dependentFieldSelector: String
  }

  connect() {
    this.boundDocumentClickHandler = this.handleDocumentClick.bind(this)
    this.boundDependentChangedHandler = this.dependentChanged.bind(this)

    // If no dependent param is specified, this is a standalone dropdown
    if (!this.dependentParamValue) {
      this.loadItems()
    } else if (this.currentDependentIdValue) {
      // Only load items if we have a dependent selected
      this.loadItems()
    } else {
      this.showSelectDependentMessage()
    }

    this.setupEventListeners()
  }

  disconnect() {
    // Remove document event listener
    document.removeEventListener('click', this.boundDocumentClickHandler)

    // Remove dependent field event listeners
    if (this.hasDependentFieldTarget) {
      this.dependentFieldTarget.removeEventListener('blur', this.boundDependentChangedHandler)
      this.dependentFieldTarget.removeEventListener('change', this.boundDependentChangedHandler)
      this.dependentFieldTarget.removeEventListener('input', this.boundDependentChangedHandler)
    } else if (this.dependentFieldSelectorValue) {
      // Remove external field listeners
      const externalField = document.querySelector(this.dependentFieldSelectorValue)
      if (externalField) {
        externalField.removeEventListener('change', this.boundDependentChangedHandler)
        externalField.removeEventListener('input', this.boundDependentChangedHandler)
      }
    }
  }

  setupEventListeners() {
    // Listen for dependent field changes
    if (this.hasDependentFieldTarget) {
      this.dependentFieldTarget.addEventListener('blur', this.boundDependentChangedHandler)
      this.dependentFieldTarget.addEventListener('change', this.boundDependentChangedHandler)
      this.dependentFieldTarget.addEventListener('input', this.boundDependentChangedHandler)
    } else if (this.dependentFieldSelectorValue) {
      // Use document selector if no local target is available
      const externalField = document.querySelector(this.dependentFieldSelectorValue)
      if (externalField) {
        externalField.addEventListener('change', this.boundDependentChangedHandler)
        externalField.addEventListener('input', this.boundDependentChangedHandler)
      }
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

  async dependentChanged(event) {
    const newDependentId = event.target.value
    const oldDependentId = this.currentDependentIdValue

    if (newDependentId !== oldDependentId.toString()) {
      this.currentDependentIdValue = newDependentId ? parseInt(newDependentId) : null

      if (this.currentDependentIdValue) {
        await this.loadItems()
      } else {
        // No dependent selected - clear items and show message
        this.clearSelection()
        this.showSelectDependentMessage()
      }
    }
  }

  async loadItems() {
    try {
      // Store current display before potentially showing loading
      this.storeCurrentDisplay()

      // Only show loading if we don't have a valid item display
      if (!this.hasValidItemDisplay()) {
        this.showLoading()
      }

      const params = new URLSearchParams()
      if (this.dependentParamValue && this.currentDependentIdValue) {
        params.append(this.dependentParamValue, this.currentDependentIdValue)
        params.append('include_reusable', 'true')
      }
      params.append('filter', 'active')

      const url = `${this.urlValue}?${params}`

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
          this.validateCurrentItem()
          this.hideLoading()
        })

        Turbo.renderStreamMessage(turboStreamHtml)
      } else {
        this.handleError(`Failed to load ${this.itemNameValue}s: ${response.statusText}`)
        this.restoreDisplayOrShowError()
      }
    } catch (error) {
      this.handleError(`Error loading ${this.itemNameValue}s: ${error.message}`)
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
    // Re-attach click listeners to item options after Turbo Stream update
    const options = this.dropdownTarget.querySelectorAll('.searchable-option')
    options.forEach(option => {
      // Remove any existing listeners by cloning the node
      const newOption = option.cloneNode(true)
      option.parentNode.replaceChild(newOption, option)

      const itemId = parseInt(newOption.dataset.itemId)
      const itemName = newOption.querySelector('.fw-normal').textContent
      const itemSubtext = newOption.querySelector('.small').textContent.trim()

      newOption.addEventListener('click', () => {
        this.selectItem({
          id: itemId,
          name: itemName,
          subtext: itemSubtext
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
      // Check if item options were added/changed
      const hasItemOptions = mutations.some(mutation =>
        Array.from(mutation.addedNodes).some(node =>
          node.nodeType === Node.ELEMENT_NODE &&
          (node.classList?.contains('searchable-option') ||
           node.querySelector?.('.searchable-option'))
        )
      )

      if (hasItemOptions) {
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

  selectItem(item) {
    this.currentItemIdValue = item.id
    this.updateSelectDisplay(item)
    this.closeDropdown()

    // Update the actual form field
    const hiddenInput = this.element.querySelector(`input[name*="[${this.itemIdParamValue}]"]`)
    if (hiddenInput) {
      hiddenInput.value = item.id

      // Dispatch change event to notify dependent dropdowns
      const changeEvent = new Event('change', { bubbles: true })
      hiddenInput.dispatchEvent(changeEvent)

      // Also dispatch input event for broader compatibility
      const inputEvent = new Event('input', { bubbles: true })
      hiddenInput.dispatchEvent(inputEvent)
    }

    // Clear any validation errors
    this.markAsValid()
  }

  updateSelectDisplay(item) {
    const display = this.selectTarget.querySelector('.select-display')
    if (display) {
      display.innerHTML = `
        <div class="fw-normal">${item.name}</div>
        <div class="small text-muted">${item.subtext}</div>
      `
    }
  }

  validateCurrentItem() {
    if (!this.currentItemIdValue) return

    // Check if the current item exists in the DOM (after Turbo Stream update)
    const validItemElement = this.dropdownTarget.querySelector(`[data-item-id="${this.currentItemIdValue}"]`)

    if (!validItemElement) {
      // Clear invalid item
      this.currentItemIdValue = null
      this.clearSelection()
      this.markAsInvalid()
    } else {
      this.markAsValid()
    }
  }

  clearSelection() {
    const display = this.selectTarget.querySelector('.select-display')
    if (display) {
      display.innerHTML = `<span class="text-muted">${this.selectPromptValue || `Select ${this.itemNameValue}...`}</span>`
    }

    const hiddenInput = this.element.querySelector(`input[name*="[${this.itemIdParamValue}]"]`)
    if (hiddenInput) {
      hiddenInput.value = ''

      // Dispatch change event to notify dependent dropdowns
      const changeEvent = new Event('change', { bubbles: true })
      hiddenInput.dispatchEvent(changeEvent)

      // Also dispatch input event for broader compatibility
      const inputEvent = new Event('input', { bubbles: true })
      hiddenInput.dispatchEvent(inputEvent)
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
    const options = this.dropdownTarget.querySelectorAll('.searchable-option')

    options.forEach(option => {
      const name = option.dataset.itemName
      const subtext = option.dataset.itemSubtext

      if (name.includes(searchTerm) || subtext.includes(searchTerm)) {
        option.style.display = 'block'
      } else {
        option.style.display = 'none'
      }
    })
  }

  handleKeyNavigation(event) {
    const visibleOptions = Array.from(this.dropdownTarget.querySelectorAll('.searchable-option'))
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
      const focused = this.dropdownTarget.querySelector('.searchable-option.focus')
      if (focused) {
        focused.click()
      }
    } else if (event.key === 'Escape') {
      this.closeDropdown()
    }
  }

  navigateOptions(options, direction) {
    const currentFocused = this.dropdownTarget.querySelector('.searchable-option.focus')
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

  hasValidItemDisplay() {
    const display = this.selectTarget.querySelector('.select-display')
    if (!display) return false

    const html = display.innerHTML
    return html &&
           !html.includes('Loading...') &&
           !html.includes(`Select ${this.itemNameValue}...`) &&
           html.includes('fw-normal') &&
           this.currentItemIdValue  // Must also have a valid item ID
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

  showSelectDependentMessage() {
    const display = this.selectTarget.querySelector('.select-display')
    if (display) {
      display.innerHTML = `<span class="text-muted">${this.dependentSelectPromptValue || `Select ${this.dependentParamValue} first...`}</span>`
    }

    // Also update the dropdown content
    const dropdownContent = this.dropdownTarget.querySelector('.dropdown-content')
    if (dropdownContent) {
      dropdownContent.innerHTML = `<div class="dropdown-item text-muted">Select a ${this.dependentParamValue} first</div>`
    }
  }

  hideLoading() {
    // Restore the item display if one is already selected
    if (this.currentItemIdValue) {
      const display = this.selectTarget.querySelector('.select-display')
      if (display) {
        // Find the selected item in the new options
        const selectedOption = this.dropdownTarget.querySelector(`[data-item-id="${this.currentItemIdValue}"]`)

        if (selectedOption) {
          const name = selectedOption.querySelector('.fw-normal').textContent
          const subtextElement = selectedOption.querySelector('.small')

          let subtextHTML = ''
          if (subtextElement) {
            // Preserve the entire structure of the subtext, including any icons or additional elements
            subtextHTML = subtextElement.innerHTML
          }

          display.innerHTML = `
            <div class="fw-normal">${name}</div>
            <div class="small text-muted">${subtextHTML}</div>
          `
          this.markAsValid()
        } else {
          // Item not found in new options - try to restore from stored display
          if (this.storedDisplayHTML && this.storedDisplayHTML.includes('fw-normal')) {
            display.innerHTML = this.storedDisplayHTML
            this.markAsValid()
          } else {
            // Item is no longer valid
            this.clearSelection()
            this.markAsInvalid()
          }
        }
      }
    } else {
      const display = this.selectTarget.querySelector('.select-display')
      if (display && display.innerHTML.includes('Loading')) {
        display.innerHTML = `<span class="text-muted">${this.selectPromptValue || `Select ${this.itemNameValue}...`}</span>`
      }
    }
  }
}
