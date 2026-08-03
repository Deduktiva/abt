import BaseLinesController from "controllers/base_lines_controller"

export default class extends BaseLinesController {
  getLineType() {
    return 'delivery_note_lines'
  }
}
