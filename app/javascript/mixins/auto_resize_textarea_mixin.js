// Mixin for auto-resizing textareas
export const AutoResizeTextareaMixin = {
  initializeAutoResizeTextareas(container = null) {
    const searchContainer = container || this.containerTarget
    const textareas = searchContainer.querySelectorAll('textarea')

    textareas.forEach(textarea => {
      // Initial resize - use requestAnimationFrame to ensure DOM is ready
      requestAnimationFrame(() => {
        this.autoResizeTextarea(textarea)
      })

      // Store bound function reference for proper cleanup
      if (!textarea.boundAutoResize) {
        textarea.boundAutoResize = () => this.autoResizeTextarea(textarea)
        textarea.addEventListener('input', textarea.boundAutoResize)
      }
    })

    // Also resize after a short delay to handle any dynamic content loading
    setTimeout(() => {
      textareas.forEach(textarea => this.autoResizeTextarea(textarea))
    }, 100)
  },

  autoResizeTextarea(textarea) {
    // Skip if textarea is not visible or not in DOM
    if (!textarea.offsetParent && textarea.offsetHeight === 0) {
      return
    }

    // Store current scroll position to maintain it
    const scrollTop = textarea.scrollTop

    // Reset height to auto to get the correct scrollHeight
    textarea.style.height = 'auto'

    // Get computed styles for accurate calculations
    const computedStyle = window.getComputedStyle(textarea)
    const lineHeight = parseInt(computedStyle.lineHeight) || 20
    const paddingTop = parseInt(computedStyle.paddingTop) || 0
    const paddingBottom = parseInt(computedStyle.paddingBottom) || 0
    const borderTop = parseInt(computedStyle.borderTopWidth) || 0
    const borderBottom = parseInt(computedStyle.borderBottomWidth) || 0

    // Calculate minimum height (3 rows)
    const minHeight = (lineHeight * 3) + paddingTop + paddingBottom + borderTop + borderBottom

    // Set height to match content, with minimum of 3 rows
    const contentHeight = textarea.scrollHeight
    const newHeight = Math.max(contentHeight, minHeight)

    textarea.style.height = newHeight + 'px'

    // Restore scroll position
    textarea.scrollTop = scrollTop
  },

  cleanupAutoResizeTextareas(container = null) {
    // Clean up auto-resize event listeners
    const searchContainer = container || this.containerTarget
    const textareas = searchContainer.querySelectorAll('textarea')
    textareas.forEach(textarea => {
      if (textarea.boundAutoResize) {
        textarea.removeEventListener('input', textarea.boundAutoResize)
        delete textarea.boundAutoResize
      }
    })
  },

  handleTextareaFieldChanged(event) {
    // Auto-resize textarea if needed
    if (event.target.tagName.toLowerCase() === 'textarea') {
      this.autoResizeTextarea(event.target)
    }
  }
}
