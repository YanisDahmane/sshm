import { Controller } from "@hotwired/stimulus"

// Submits its form as soon as a field changes (filters).
export default class extends Controller {
  submit() {
    this.element.requestSubmit()
  }
}
