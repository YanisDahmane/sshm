require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]

  # The app replaces confirm() with its own dialog (app/javascript/confirm_dialog.js).
  # Looked up from the document root, whatever the current `within` scope.
  def accept_app_confirm(button = nil)
    yield
    dialog = page.document.find("#confirm-dialog[open]")
    button ? dialog.click_on(button) : dialog.find("[data-confirm-accept]").click
    page.document.assert_no_selector "#confirm-dialog[open]"
  end

  def dismiss_app_confirm
    yield
    page.document.find("#confirm-dialog[open]").click_on("Annuler")
    page.document.assert_no_selector "#confirm-dialog[open]"
  end
end
