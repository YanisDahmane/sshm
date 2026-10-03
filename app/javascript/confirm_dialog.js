// Replaces the browser's confirm() for data-turbo-confirm with the app's
// <dialog id="confirm-dialog">. The accept button's label and colour come from
// data-confirm-label / data-confirm-variant ("danger") on the submitter or form.
export function confirmDialog(message, form, submitter) {
  const dialog = document.getElementById("confirm-dialog")
  if (!dialog) return Promise.resolve(window.confirm(message))

  const option = (name) => submitter?.dataset[name] || form?.dataset[name]
  const accept = dialog.querySelector("[data-confirm-accept]")
  dialog.querySelector("[data-confirm-message]").textContent = message
  accept.textContent = option("confirmLabel") || "Confirmer"
  accept.dataset.variant = option("confirmVariant") || "primary"

  dialog.returnValue = ""
  dialog.showModal()
  accept.focus()

  return new Promise((resolve) => {
    dialog.addEventListener("close", () => resolve(dialog.returnValue === "confirm"), { once: true })
  })
}

// Clicking the backdrop (outside the panel) cancels.
document.addEventListener("click", (event) => {
  if (event.target.id === "confirm-dialog") event.target.close("cancel")
})
