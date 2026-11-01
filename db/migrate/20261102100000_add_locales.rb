# The interface language: chosen by each user (nil = the browser's), a
# default for the instance, one per notification channel (nil = the
# instance's) and per invitation (the email and the new account).
class AddLocales < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :locale, :string
    add_column :invitations, :locale, :string
    add_column :notification_channels, :locale, :string
    # Existing installations were in French; new ones start in English.
    add_column :app_settings, :default_locale, :string, null: false, default: "fr"
    change_column_default :app_settings, :default_locale, from: "fr", to: "en"
  end
end
