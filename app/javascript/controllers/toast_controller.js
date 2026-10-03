import { Controller } from "@hotwired/stimulus"

// A flash toast: slides in, disappears after `duration` ms (paused while
// hovered) or when its close button is clicked.
export default class extends Controller {
  static values = { duration: { type: Number, default: 5000 } }

  connect() {
    requestAnimationFrame(() => (this.element.dataset.state = "visible"))
    this.resume()
  }

  disconnect() {
    clearTimeout(this.timeout)
  }

  pause() {
    clearTimeout(this.timeout)
  }

  resume() {
    this.timeout = setTimeout(() => this.dismiss(), this.durationValue)
  }

  dismiss() {
    clearTimeout(this.timeout)
    this.element.dataset.state = "hidden"
    setTimeout(() => this.element.remove(), 300)
  }
}
