import { Controller } from "@hotwired/stimulus"

// Quick search over pages, servers and profiles. Opens with ⌘K / Ctrl+K or
// the navbar button; arrows to move, Enter to open, Escape to close.
export default class extends Controller {
  static targets = ["dialog", "input", "results", "empty", "items"]

  connect() {
    this.items = JSON.parse(this.itemsTarget.textContent)
    this.onKeydown = (event) => {
      if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "k") {
        event.preventDefault()
        this.dialogTarget.open ? this.close() : this.open()
      }
    }
    document.addEventListener("keydown", this.onKeydown)
    this.dialogTarget.addEventListener("click", (event) => { if (event.target === this.dialogTarget) this.close() })
  }

  disconnect() {
    document.removeEventListener("keydown", this.onKeydown)
  }

  open() {
    this.inputTarget.value = ""
    this.filter()
    this.dialogTarget.showModal()
    this.inputTarget.focus()
  }

  close() {
    this.dialogTarget.close()
  }

  filter() {
    const words = normalize(this.inputTarget.value).split(/\s+/).filter(Boolean)
    this.matches = this.items.filter((item) => {
      const haystack = normalize(`${item.label} ${item.hint || ""} ${item.group}`)
      return words.every((word) => haystack.includes(word))
    })
    this.selected = 0
    this.render()
  }

  navigate(event) {
    if (event.key === "ArrowDown" || event.key === "ArrowUp") {
      event.preventDefault()
      const step = event.key === "ArrowDown" ? 1 : -1
      this.selected = (this.selected + step + this.matches.length) % Math.max(this.matches.length, 1)
      this.render()
    } else if (event.key === "Enter") {
      event.preventDefault()
      this.visit(this.matches[this.selected])
    }
  }

  visit(item) {
    if (!item) return
    this.close()
    window.Turbo.visit(item.url)
  }

  render() {
    this.resultsTarget.replaceChildren()
    this.emptyTarget.hidden = this.matches.length > 0
    let group = null

    this.matches.forEach((item, index) => {
      if (item.group !== group) {
        group = item.group
        const heading = document.createElement("li")
        heading.className = "px-2 pb-1 pt-3 text-xs font-semibold uppercase tracking-wide text-slate-400"
        heading.textContent = group
        this.resultsTarget.append(heading)
      }

      const option = document.createElement("li")
      option.setAttribute("role", "option")
      option.setAttribute("aria-selected", index === this.selected)
      option.className = "command-palette-item flex cursor-pointer items-center justify-between gap-3 rounded-md px-3 py-2 text-sm aria-selected:bg-indigo-600 aria-selected:text-white"
      const label = document.createElement("span")
      label.className = "truncate font-medium"
      label.textContent = item.label
      option.append(label)
      if (item.hint) {
        const hint = document.createElement("span")
        hint.className = "truncate font-mono text-xs opacity-70"
        hint.textContent = item.hint
        option.append(hint)
      }
      option.addEventListener("mousemove", () => { if (this.selected !== index) { this.selected = index; this.render() } })
      option.addEventListener("click", () => this.visit(item))
      this.resultsTarget.append(option)
      if (index === this.selected) option.scrollIntoView({ block: "nearest" })
    })
  }
}

function normalize(text) {
  return text.normalize("NFD").replace(/\p{Diacritic}/gu, "").toLowerCase()
}
