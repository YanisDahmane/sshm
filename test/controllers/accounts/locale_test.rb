require "test_helper"

# The interface language: the user's, else the browser's, else the
# instance's (the fixtures' instance is in French).
class LocaleTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  test "without a choice nor a browser language, the instance's language" do
    sign_in users(:one)
    get account_path
    assert_select "html[lang=fr]"

    app_settings(:main).update!(default_locale: "en")
    get account_path
    assert_select "html[lang=en]"
  end

  test "the browser's language comes before the instance's, if Elio has it" do
    sign_in users(:one)
    get account_path, headers: { "Accept-Language" => "en-GB,en;q=0.9" }
    assert_select "html[lang=en]"

    get account_path, headers: { "Accept-Language" => "de-DE,de;q=0.9" }
    assert_select "html[lang=fr]"
  end

  test "the user's choice comes first" do
    users(:one).update!(locale: "fr")
    sign_in users(:one)
    get account_path, headers: { "Accept-Language" => "en" }
    assert_select "html[lang=fr]"
  end

  test "the public pages follow the browser" do
    get new_user_session_path, headers: { "Accept-Language" => "en" }
    assert_select "html[lang=en]"
    get new_user_session_path, headers: { "Accept-Language" => "fr" }
    assert_select "html[lang=fr]"
  end

  test "a user chooses a language, answered in that language, or goes back to automatic" do
    sign_in users(:one)
    get account_path
    assert_select "#language select[name='user[locale]'] option", count: 3
    assert_select "#language option[value='']", text: "Automatique (navigateur)"
    assert_select "#language option[value=en]", text: "English"
    assert_select "#language option[value=fr]", text: "Français"

    patch locale_account_path, params: { user: { locale: "en" } }
    assert_redirected_to account_path(anchor: "language")
    assert_equal "Language saved.", flash[:notice]
    assert_equal "en", users(:one).reload.locale

    patch locale_account_path, params: { user: { locale: "" } }
    assert_nil users(:one).reload.locale
    assert_equal "Langue enregistrée.", flash[:notice]
  end

  test "an unknown language is refused" do
    sign_in users(:one)
    patch locale_account_path, params: { user: { locale: "de" } }
    assert_equal "Cette langue n'est pas disponible.", flash[:alert]
    assert_nil users(:one).reload.locale
  end

  test "an admin sets the instance's language" do
    sign_in users(:one)
    get settings_path
    assert_select "#language select[name='app_setting[default_locale]'] option[selected][value=fr]"

    patch settings_language_path, params: { app_setting: { default_locale: "en" } }
    assert_redirected_to settings_path(anchor: "language")
    assert_equal "en", app_settings(:main).reload.default_locale

    patch settings_language_path, params: { app_setting: { default_locale: "xx" } }
    assert_equal "This language is not available.", flash[:alert] # the instance is now in English
    assert_equal "en", app_settings(:main).reload.default_locale
  end

  test "the page carries the texts of the JavaScript controllers in its language" do
    sign_in users(:one)
    get account_path, headers: { "Accept-Language" => "en" }
    assert_equal "Copied", JSON.parse(css_select("script#elio-i18n").first.text).dig("clipboard", "copied")
  end

  test "jobs run in the instance's language, whoever started them" do
    app_settings(:main).update!(default_locale: "en")
    locale = nil
    job = Class.new(ApplicationJob) { define_method(:perform) { locale = I18n.locale } }
    I18n.with_locale(:fr) { job.perform_now }
    assert_equal :en, locale
  end
end
