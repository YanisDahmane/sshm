import { Controller } from "@hotwired/stimulus"

// While a ping request is in flight, swaps the affected status badges for a
// spinning "checking" badge. The Turbo Stream response then replaces each
// badge with its fresh status. Pair with quiet-submit to hide the progress bar.
export default class extends Controller {
  static targets = ["badge", "checking"]

  start({ params: { badge: badgeId } }) {
    this.originals = this.badgeTargets
      .filter((badge) => !badgeId || badge.id === badgeId)
      .map((badge) => {
        const checking = this.checkingTarget.content.firstElementChild.cloneNode(true)
        checking.id = badge.id
        badge.replaceWith(checking)
        return badge
      })
  }

  finish({ detail: { success } }) {
    // On failure no stream arrives: put the previous badges back.
    if (!success) this.originals?.forEach((badge) => document.getElementById(badge.id)?.replaceWith(badge))
    this.originals = []
  }
}
