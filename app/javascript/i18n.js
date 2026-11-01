// Texts of the JavaScript controllers, in the language of the page: the
// js.* keys of config/locales/<lang>/js.yml, written in the page by
// LocaleHelper#js_translations_tag (in <body>, so that Turbo replaces them
// when the language changes).
//
//   t("clipboard.copied")
//   t("relative_time.minutes_ago", { count: 5 })   // plural forms of the language
let element = null
let dictionary = {}

function translations() {
  const current = document.getElementById("elio-i18n")
  if (current !== element) {
    element = current
    dictionary = current ? JSON.parse(current.textContent) : {}
  }
  return dictionary
}

export function locale() {
  return document.documentElement.lang || "en"
}

export function t(key, variables = {}) {
  let value = key.split(".").reduce((node, part) => node?.[part], translations())
  if (value && typeof value === "object" && "count" in variables) {
    value = value[new Intl.PluralRules(locale()).select(variables.count)] ?? value.other
  }
  if (typeof value !== "string") return key
  return value.replace(/%\{(\w+)\}/g, (_, name) => String(variables[name] ?? ""))
}
