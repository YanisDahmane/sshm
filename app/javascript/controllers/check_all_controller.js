import { Controller } from "@hotwired/stimulus"

// Checks every checkbox target, or unchecks them all when they already are.
export default class extends Controller {
  static targets = ["checkbox"]

  toggle() {
    const check = !this.checkboxTargets.every((checkbox) => checkbox.checked)
    this.checkboxTargets.forEach((checkbox) => (checkbox.checked = check))
  }
}
