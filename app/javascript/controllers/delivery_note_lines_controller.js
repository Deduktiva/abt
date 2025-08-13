import BaseLinesController from "controllers/base_lines_controller"

export default class extends BaseLinesController {
  getLineType() {
    return 'delivery_note_lines'
  }

  getIdPrefix() {
    return 'delivery_note_delivery_note_lines_attributes_'
  }

}
