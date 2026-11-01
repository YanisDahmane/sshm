require "test_helper"

# Every language has every text: the same keys, the same %{variables}, no
# empty value. The reference is English.
class LocaleFilesTest < ActiveSupport::TestCase
  PLURAL_KEYS = %w[zero one two few many other].freeze

  def self.texts(locale)
    Dir[File.join(Elio::Locales::DIRECTORY, locale.to_s, "*.yml")].each_with_object({}) do |path, texts|
      tree = YAML.safe_load_file(path, aliases: true).fetch(locale.to_s) { raise "#{path} must start with #{locale}:" }
      flatten(tree, "", texts, path)
    end
  end

  # { "accounts.language.title" => [value, file] }; plural forms are one key
  # (their forms differ between languages).
  def self.flatten(node, prefix, texts, path)
    if node.is_a?(Hash) && node.any? && (node.keys.map(&:to_s) - PLURAL_KEYS).empty?
      texts[prefix.delete_suffix(".")] = [ node.values.map(&:to_s).join(" | "), path ]
    elsif node.is_a?(Hash)
      node.each { |key, value| flatten(value, "#{prefix}#{key}.", texts, path) }
    else
      key = prefix.delete_suffix(".")
      raise "#{key} is defined twice (#{path}, #{texts[key].last})" if texts.key?(key)

      texts[key] = [ node, path ]
    end
  end

  def self.variables(value) = value.to_s.scan(/%\{(\w+)\}/).flatten.uniq.sort

  REFERENCE = texts(:en)

  test "every language folder has a meta.yml with the language's name" do
    Elio::Locales.available.each do |locale|
      assert_predicate texts = self.class.texts(locale)["elio.language_name"]&.first, :present?, "#{locale}/meta.yml"
    end
  end

  (Elio::Locales.available - [ :en ]).each do |locale|
    test "#{locale} has the same texts as English" do
      texts = self.class.texts(locale)
      assert_empty REFERENCE.keys - texts.keys, "missing in #{locale}"
      assert_empty texts.keys - REFERENCE.keys, "in #{locale} but not in English"
    end

    test "#{locale} uses the same variables as English" do
      texts = self.class.texts(locale)
      mismatches = REFERENCE.filter_map do |key, (value, _)|
        next unless texts.key?(key)

        expected = self.class.variables(value)
        actual = self.class.variables(texts[key].first)
        "#{key}: #{actual.inspect} instead of #{expected.inspect}" unless expected == actual
      end
      assert_empty mismatches
    end
  end

  test "no text is empty" do
    empty = Elio::Locales.available.flat_map do |locale|
      self.class.texts(locale).filter_map { |key, (value, path)| "#{File.basename(File.dirname(path))}/#{File.basename(path)}: #{key}" if value.to_s.strip.empty? }
    end
    assert_empty empty
  end

  test "a file only holds its own language" do
    Elio::Locales.files.each do |path|
      locale = File.basename(File.dirname(path))
      assert_equal [ locale ], YAML.safe_load_file(path, aliases: true).keys, path
    end
  end
end
