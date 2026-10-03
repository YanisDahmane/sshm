import { Controller } from "@hotwired/stimulus"

// Hides Turbo's progress bar while this form submits, for forms that show
// their own loading state (spinning icon, placeholder badge…).
export default class extends Controller {
  connect() {
    this.start = () => document.documentElement.classList.add("hide-turbo-progress")
    this.finish = () => document.documentElement.classList.remove("hide-turbo-progress")
    this.element.addEventListener("turbo:submit-start", this.start)
    this.element.addEventListener("turbo:submit-end", this.finish)
  }

  disconnect() {
    this.element.removeEventListener("turbo:submit-start", this.start)
    this.element.removeEventListener("turbo:submit-end", this.finish)
    this.finish()
  }
}
