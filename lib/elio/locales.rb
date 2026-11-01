module Elio
  # The languages of the interface: one folder per language in
  # config/locales (config/locales/<code>/*.yml, meta.yml giving its name in
  # that language). Adding a language is adding a folder.
  module Locales
    DIRECTORY = File.expand_path("../../config/locales", __dir__)
    DEFAULT = :en

    def self.available
      @available ||= Dir[File.join(DIRECTORY, "*", "meta.yml")].map { |path| File.basename(File.dirname(path)).to_sym }.sort
    end

    def self.files = Dir[File.join(DIRECTORY, "*", "*.yml")]

    # :fr for "fr", "fr-FR", :FR; nil for a language Elio does not have.
    def self.find(code)
      code = code.to_s.strip.downcase.tr("_", "-")
      return if code.empty?

      available.find { |locale| locale.to_s.downcase == code } ||
        available.find { |locale| locale.to_s.downcase == code.split("-").first }
    end

    # The first language of an Accept-Language header that Elio has, by
    # preference ("fr-CH, fr;q=0.9, en;q=0.8" → :fr).
    def self.from_accept_language(header)
      header.to_s.split(",").filter_map do |part|
        code, *params = part.split(";").map(&:strip)
        quality = params.find { |param| param.start_with?("q=") }&.delete_prefix("q=")&.to_f || 1.0
        [ code, quality ] if code.present? && code != "*" && quality.positive?
      end.sort_by.with_index { |(_, quality), index| [ -quality, index ] }.each do |code, _|
        locale = find(code)
        return locale if locale
      end
      nil
    end

    # The name of each language in that language: { en: "English", fr: "Français" }.
    def self.names = available.index_with { |locale| I18n.t("elio.language_name", locale: locale) }
  end
end
