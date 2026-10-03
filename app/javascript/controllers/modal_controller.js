import { Controller } from "@hotwired/stimulus"

// Opens / closes a <dialog> target as a modal; a click on the backdrop closes it
// (Escape is handled natively by <dialog>).
export default class extends Controller {
  static targets = ["dialog"]

  open() {
    this.dialogTarget.showModal()
  }

  close() {
    this.dialogTarget.close()
  }

  backdropClose(event) {
    if (event.target === this.dialogTarget) this.close()
  }
}
