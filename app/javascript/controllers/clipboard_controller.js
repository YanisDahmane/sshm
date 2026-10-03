import { Controller } from "@hotwired/stimulus"

// Copies the source's value to the clipboard and briefly confirms it.
export default class extends Controller {
  static targets = ["source", "idle", "copied"]

  async copy() {
    await navigator.clipboard.writeText(this.sourceTarget.value ?? this.sourceTarget.textContent)

    this.idleTarget.hidden = true
    this.copiedTarget.hidden = false
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => {
      this.idleTarget.hidden = false
      this.copiedTarget.hidden = true
    }, 2000)
  }
}
