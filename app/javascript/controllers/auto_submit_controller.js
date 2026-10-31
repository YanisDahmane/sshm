import { Controller } from "@hotwired/stimulus"

// Submits its form as soon as a field changes (filters), or shortly after
// the user stops typing (submitLater, for search fields).
export default class extends Controller {
  submit() {
    clearTimeout(this.timeout)
    this.element.requestSubmit()
  }

  submitLater() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => this.element.requestSubmit(), 300)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }
}
