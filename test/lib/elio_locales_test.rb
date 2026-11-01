require "test_helper"

class ElioLocalesTest < ActiveSupport::TestCase
  test "the languages are the folders of config/locales" do
    assert_equal %i[en fr], Elio::Locales.available
    assert_equal Elio::Locales.available, I18n.available_locales.sort
    assert_equal({ en: "English", fr: "Français" }, Elio::Locales.names)
  end

  test "find accepts a region, any case, and refuses unknown languages" do
    assert_equal :fr, Elio::Locales.find("fr")
    assert_equal :fr, Elio::Locales.find("fr-CH")
    assert_equal :en, Elio::Locales.find("EN_us")
    assert_nil Elio::Locales.find("de")
    assert_nil Elio::Locales.find("")
    assert_nil Elio::Locales.find(nil)
  end

  test "from_accept_language takes the preferred language that Elio has" do
    assert_equal :fr, Elio::Locales.from_accept_language("fr-CH, fr;q=0.9, en;q=0.8")
    assert_equal :en, Elio::Locales.from_accept_language("de-DE, de;q=0.9, en;q=0.5, fr;q=0.4")
    assert_equal :fr, Elio::Locales.from_accept_language("en;q=0.2, fr")
    assert_nil Elio::Locales.from_accept_language("de, *;q=0.1")
    assert_nil Elio::Locales.from_accept_language("en;q=0")
    assert_nil Elio::Locales.from_accept_language(nil)
  end
end
