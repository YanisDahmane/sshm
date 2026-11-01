require "test_helper"
require "nokogiri"

# The website (site/build.rb): every page in both languages, no broken
# internal link or image, every command of config/ssh_commands.yml listed.
class SiteBuildTest < ActiveSupport::TestCase
  # One folder per test: the parallel workers must not share it.
  setup do
    @out = Rails.root.join("tmp/test/site-#{SecureRandom.hex(4)}")
    assert system({ "ELIO_SITE_OUT" => @out.to_s, "ELIO_SITE_PNG" => "1" }, RbConfig.ruby, Rails.root.join("site/build.rb").to_s, out: File::NULL), "site/build.rb failed"
  end

  teardown { FileUtils.rm_rf(@out) }

  def pages = Dir[@out.join("**/*.html")].sort

  test "every page in English and French, with a title, a description and the other language" do
    assert_equal 10, pages.size
    pages.each do |path|
      document = Nokogiri::HTML(File.read(path))
      relative = Pathname(path).relative_path_from(@out).to_s
      assert_equal relative.start_with?("fr/") ? "fr" : "en", document.at("html")["lang"], relative
      assert document.at("title").text.include?("Elio"), relative
      assert document.at("meta[name=description]")["content"].present?, relative
      assert_equal 2, document.css("link[rel=alternate][hreflang]").size, relative
    end
  end

  test "no broken internal link, image or stylesheet" do
    pages.each do |path|
      document = Nokogiri::HTML(File.read(path))
      targets = document.css("a[href], img[src], link[href], script[src]").map { |node| node["href"] || node["src"] }
      targets.reject { |target| target.match?(%r{\A(https?:|mailto:|#)}) }.each do |target|
        file = File.expand_path(target.split("#").first, File.dirname(path))
        file = File.join(file, "index.html") if File.directory?(file)
        next if file.end_with?("site.css") # compiled by bin/site afterwards

        assert File.exist?(file), "#{Pathname(path).relative_path_from(@out)} → #{target}"
      end
    end
  end

  test "the security page lists every command Elio can run, the writing ones marked" do
    document = Nokogiri::HTML(File.read(@out.join("security.html")))
    keys = Ssh::Commands.all.keys.reject { |key| Ssh::Commands.all[key].description.blank? }
    assert_equal keys.sort, document.css("ul.commands li").map { |item| item["id"] }.sort
    assert_equal Ssh::Commands.all.values.select(&:writes?).map(&:key).sort, document.css("ul.commands li").select { |item| item.at_css(".badge.bg-warn-soft") }.map { |item| item["id"] }.sort
  end

  test "the version shown is Elio::VERSION" do
    assert_includes File.read(@out.join("index.html")), "v#{Elio::VERSION}"
  end
end
