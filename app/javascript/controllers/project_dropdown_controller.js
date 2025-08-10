import SearchableDropdownController from "./searchable_dropdown_controller"

export default class extends SearchableDropdownController {
  static targets = ["select", "search", "dropdown", "customerField"]
  static values = {
    currentCustomerId: Number,
    currentProjectId: Number,
    url: { type: String, default: "/projects" },
    dependentParam: { type: String, default: "customer_id" },
    itemName: { type: String, default: "project" },
    itemIdParam: { type: String, default: "project_id" },
    selectPrompt: { type: String, default: "Select project..." },
    dependentSelectPrompt: { type: String, default: "Select customer first..." },
    dependentFieldSelector: String
  }

  connect() {
    // Map project-specific values to generic ones before calling super
    this.currentDependentIdValue = this.currentCustomerIdValue
    this.currentItemIdValue = this.currentProjectIdValue

    super.connect()
  }

  disconnect() {
    // Remove customer field listeners before calling super
    if (this.hasCustomerFieldTarget) {
      this.customerFieldTarget.removeEventListener('blur', this.boundCustomerChangedHandler)
      this.customerFieldTarget.removeEventListener('change', this.boundCustomerChangedHandler)
      this.customerFieldTarget.removeEventListener('input', this.boundCustomerChangedHandler)
    }

    super.disconnect()
  }

  setupEventListeners() {
    super.setupEventListeners()

    // Add customer field listeners in addition to generic dependent field handling
    if (this.hasCustomerFieldTarget) {
      this.boundCustomerChangedHandler = this.customerChanged.bind(this)
      this.customerFieldTarget.addEventListener('blur', this.boundCustomerChangedHandler)
      this.customerFieldTarget.addEventListener('change', this.boundCustomerChangedHandler)
      this.customerFieldTarget.addEventListener('input', this.boundCustomerChangedHandler)
    }
  }

  async customerChanged(event) {
    const newCustomerId = event.target.value
    const oldCustomerId = this.currentCustomerIdValue

    if (newCustomerId !== oldCustomerId.toString()) {
      this.currentCustomerIdValue = newCustomerId ? parseInt(newCustomerId) : null
      // Update the generic dependent value
      this.currentDependentIdValue = this.currentCustomerIdValue

      if (this.currentCustomerIdValue) {
        await this.loadItems()
      } else {
        // No customer selected - clear projects and show message
        this.clearSelection()
        this.showSelectDependentMessage()
      }
    }
  }

  // Override to handle project-specific behavior while delegating to parent
  selectItem(item) {
    this.currentProjectIdValue = item.id
    this.currentItemIdValue = item.id
    super.selectItem(item)
  }

  // Override to sync project value changes
  currentProjectIdValueChanged() {
    this.currentItemIdValue = this.currentProjectIdValue
  }

  currentCustomerIdValueChanged() {
    this.currentDependentIdValue = this.currentCustomerIdValue
  }
}
