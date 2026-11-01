import { Controller } from "@hotwired/stimulus"
import { t } from "i18n"

// Keeps a <time> showing `prefix` + a relative time up to date ("3 minutes
// ago", "in 9 minutes"); shows `expired` once the time has passed when
// given. Same rules and texts (js.relative_time) as
// ApplicationHelper#relative_time_in_words.
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
  if (Math.abs(seconds) < 60) return t(seconds > 0 ? "relative_time.within_a_minute" : "relative_time.just_now")

  const minutes = Math.round(Math.abs(seconds) / 60)
  const hours = Math.round(minutes / 60)
  let time
  if (minutes < 60) time = t("relative_time.minutes", { count: minutes })
  else if (hours < 24) time = t("relative_time.hours", { count: hours })
  else time = t("relative_time.days", { count: Math.round(hours / 24) })

  return t(seconds > 0 ? "relative_time.from_now" : "relative_time.ago", { time })
}
