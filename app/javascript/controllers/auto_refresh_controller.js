import { Controller } from "@hotwired/stimulus"

// Reloads the enclosing <turbo-frame> from the current page after `interval`
// ms. Put it on an element inside the frame that is only rendered while
// something is in progress: the reloaded content without it stops the
// refreshing. The frame must not have a src pointing to the page itself in
// the HTML (Turbo refuses it), so it is set here.
export default class extends Controller {
  static values = { interval: { type: Number, default: 2000 } }

  connect() {
    this.timeout = setTimeout(() => this.refresh(), this.intervalValue)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }

  refresh() {
    const frame = this.element.closest("turbo-frame")
    if (!frame) return

    if (frame.src) {
      frame.reload()
    } else {
      frame.src = window.location.href
    }
  }
}
