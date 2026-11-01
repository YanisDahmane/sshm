module LocaleHelper
  # Options of a language select, each in its own language, with an optional
  # first "automatic" choice (blank value).
  def locale_options(blank: nil)
    options = Elio::Locales.names.map { |locale, name| [ name, locale.to_s ] }
    blank ? [ [ blank, "" ], *options ] : options
  end

  # The texts of the JavaScript controllers (config/locales/<lang>/js.yml),
  # read by app/javascript/i18n.js.
  def js_translations_tag
    tag.script(json_escape(I18n.t("js").to_json).html_safe, type: "application/json", id: "elio-i18n", nonce: content_security_policy_nonce)
  end
end
