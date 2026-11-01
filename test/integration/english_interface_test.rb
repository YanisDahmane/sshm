require "test_helper"

# The interface read in English has no French text left: every text of the
# pages listed here comes from the translations. Data (server names,
# messages from the servers) is excluded by the fixtures, which are written
# without French words.
class EnglishInterfaceTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  # Accented letters of French, French punctuation, and common French words.
  FRENCH = /[àâçéèêëîïôûùüÿœ«»]|\b(?:le|la|les|des|du|une|est|sont|aucun|aucune|pour|avec|sans|dans|sur|serveurs?|clés?|tâches?|paramètres|groupes?|mise|jour|activité|vue|ensemble|voir|tout|rien|nouveaux?|nouvelles?|ajouter|supprimer|modifier|enregistrer|lancer|retour|fermer|oui|non)\b/i

  # Texts and attributes a user reads, but those of `except` (data).
  def self.french_texts(html, scope: nil, except: [])
    document = Nokogiri::HTML(html)
    roots = scope ? document.css(scope) : [ document.at("body") || document ]
    roots.flat_map do |root|
      except.each { |selector| root.css(selector).each(&:remove) }
      root.css("script, style, template").each(&:remove)
      texts = root.xpath(".//text()").map(&:text)
      texts += root.css("[title], [aria-label], [placeholder], [alt]").flat_map { |node| %w[title aria-label placeholder alt].filter_map { node[_1] } }
      texts.map(&:squish).reject(&:empty?).select { |text| text.match?(FRENCH) }
    end.uniq
  end

  # Parts of every page.
  LAYOUT = [ ".sidebar", "#command-palette", "#confirm-dialog", "nav.pagination" ].freeze

  setup do
    app_settings(:main).update!(default_locale: "en")
    sign_in users(:one)
  end

  def assert_english(path, scope: nil, except: [])
    get path
    assert_response :success
    leftovers = self.class.french_texts(response.body, scope: scope, except: except)
    assert_empty leftovers, "French text on #{path}#{" (#{scope})" if scope}"
  end

  test "the layout of the signed-in pages" do
    assert_english root_path, scope: LAYOUT.join(", "), except: [ ".sidebar-groups", ".account-link" ]
  end

  test "the check finds French" do
    app_settings(:main).update!(default_locale: "fr")
    get root_path
    assert_includes self.class.french_texts(response.body, scope: ".sidebar"), "Vue d'ensemble"
  end

  test "the dictionary of the JavaScript controllers" do
    get root_path
    texts = css_select("script#elio-i18n").first.text
    assert_no_match FRENCH, JSON.parse(texts).to_s
  end
end
