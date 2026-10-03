import { Controller } from "@hotwired/stimulus"

// Checks every checkbox target, or unchecks them all when they already are.
// toggleGroup does the same for the checkboxes whose data-groups (space
// separated ids) contain the clicked button's data-check-all-group-param.
export default class extends Controller {
  static targets = ["checkbox"]

  toggle() {
    this.#toggle(this.checkboxTargets)
  }

  toggleGroup({ params: { group } }) {
    this.#toggle(this.checkboxTargets.filter((checkbox) => (checkbox.dataset.groups || "").split(" ").includes(String(group))))
  }

  #toggle(checkboxes) {
    const check = !checkboxes.every((checkbox) => checkbox.checked)
    checkboxes.forEach((checkbox) => (checkbox.checked = check))
  }
}
