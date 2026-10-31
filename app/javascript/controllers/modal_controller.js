import { Controller } from "@hotwired/stimulus"

// Opens / closes a <dialog> target as a modal; a click on the backdrop closes it
// (Escape is handled natively by <dialog>). With data-modal-open-value="true",
// the dialog opens as soon as it is rendered (e.g. re-rendered with errors).
export default class extends Controller {
  static targets = ["dialog"]
  static values = { open: Boolean }

  connect() {
    if (this.openValue) this.open()
  }

  open() {
    if (!this.dialogTarget.open) this.dialogTarget.showModal()
  }

  close() {
    this.dialogTarget.close()
  }

  backdropClose(event) {
    if (event.target === this.dialogTarget) this.close()
  }
}
