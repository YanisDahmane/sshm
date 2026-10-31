import { Controller } from "@hotwired/stimulus"

// Opens the sidebar as a drawer on small screens (it is always visible from
// the `lg` breakpoint). Closes on the backdrop, Escape and page changes.
export default class extends Controller {
  static targets = ["panel", "backdrop"]

  open() {
    this.panelTarget.classList.remove("-translate-x-full")
    this.backdropTarget.classList.remove("hidden")
  }

  close() {
    this.panelTarget.classList.add("-translate-x-full")
    this.backdropTarget.classList.add("hidden")
  }

  closeOnEscape(event) {
    if (event.key === "Escape") this.close()
  }
}
