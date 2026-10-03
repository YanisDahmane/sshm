import { Controller } from "@hotwired/stimulus"

// Keeps a <time> showing `prefix` + a French relative time up to date
// ("il y a 3 minutes", "dans 9 minutes"); shows `expired` once the time has
// passed when given. Same rules as ApplicationHelper#relative_time_in_words.
export default class extends Controller {
  static values = { datetime: String, prefix: String, expired: String }

  connect() {
    this.update()
    this.timer = setInterval(() => this.update(), 15000)
  }

  disconnect() {
    clearInterval(this.timer)
  }

  update() {
    const seconds = Math.round((new Date(this.datetimeValue) - Date.now()) / 1000)

    if (this.hasExpiredValue && seconds <= 0) {
      this.element.textContent = this.expiredValue
    } else {
      this.element.textContent = this.prefixValue + inWords(seconds)
    }
  }
}

function inWords(seconds) {
  if (Math.abs(seconds) < 60) return seconds > 0 ? "dans moins d'une minute" : "à l'instant"

  const minutes = Math.round(Math.abs(seconds) / 60)
  const hours = Math.round(minutes / 60)
  let words
  if (minutes < 60) words = plural(minutes, "minute")
  else if (hours < 24) words = plural(hours, "heure")
  else words = plural(Math.round(hours / 24), "jour")

  return seconds > 0 ? `dans ${words}` : `il y a ${words}`
}

function plural(count, unit) {
  return `${count} ${unit}${count > 1 ? "s" : ""}`
}
