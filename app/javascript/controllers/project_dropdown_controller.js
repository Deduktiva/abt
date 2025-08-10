import SearchableDropdownController from "controllers/searchable_dropdown_controller"

export default class extends SearchableDropdownController {
  static values = {
    url: { type: String, default: "/projects" },
    dependentParam: { type: String, default: "customer_id" },
    itemName: { type: String, default: "project" },
    itemIdParam: { type: String, default: "project_id" },
    selectPrompt: { type: String, default: "Select project..." },
    dependentSelectPrompt: { type: String, default: "Select customer first..." },
    dependentFieldSelector: String
  }
}
