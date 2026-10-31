import { Controller } from "@hotwired/stimulus"

// Light / dark theme toggle. The choice is remembered in localStorage
// ("elio-theme"); without one, the OS preference applies (see the inline
// script of the layouts, which sets the class before the first paint).
export default class extends Controller {
  static targets = ["label"]

  connect() {
    this.update()
  }

  toggle() {
    const dark = !document.documentElement.classList.contains("dark")
    localStorage.setItem("elio-theme", dark ? "dark" : "light")
    document.documentElement.classList.toggle("dark", dark)
    this.update()
  }

  update() {
    const dark = document.documentElement.classList.contains("dark")
    this.element.setAttribute("aria-pressed", dark)
    if (this.hasLabelTarget) this.labelTarget.textContent = dark ? "Thème clair" : "Thème sombre"
  }
}
