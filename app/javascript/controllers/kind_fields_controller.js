import { Controller } from "@hotwired/stimulus"

// Shows only the fields of the selected kind: elements with
// data-kinds="slack discord" are hidden unless the checked radio of the
// "kind" target has one of these values.
export default class extends Controller {
  static targets = ["kind", "field"]

  connect() {
    this.update()
  }

  update() {
    const kind = this.kindTargets.find((radio) => radio.checked)?.value
    this.fieldTargets.forEach((field) => {
      const visible = !kind || field.dataset.kinds.split(" ").includes(kind)
      field.hidden = !visible
      field.querySelectorAll("input, textarea").forEach((input) => { input.disabled = !visible })
    })
  }
}
