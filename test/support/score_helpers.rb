# Score providers in tests: the HTTP answers and downloaded files come from
# test/fixtures/files/scores (real answers recorded on 2026-11-01).
module ScoreHelpers
  def score_fixture(name) = file_fixture("scores/#{name}")

  # Integrations::Http.get answered from { url fragment => fixture name | :not_found | :limited }.
  def with_score_answers(answers, &block)
    get = lambda do |url, service:, **|
      _, answer = answers.find { |fragment, _| url.include?(fragment) }
      case answer
      when nil, :not_found then raise Integrations::Error, "#{service} a répondu 404 : Not Found"
      when :limited then raise Integrations::Error, "#{service} a répondu 429 : Too Many Requests"
      else score_fixture(answer).read
      end
    end
    stub_method(Integrations::Http, :get, get, &block)
  end

  # Vulnerabilities::Download.open yielding fixtures, by file name in the URL.
  def with_score_downloads(files, &block)
    downloaded = []
    open = lambda do |url, **, &yielded|
      downloaded << url
      name = files.find { |fragment, _| url.include?(fragment) }&.last or raise Vulnerabilities::Error, "Téléchargement impossible (HTTP 404) : #{url}"
      yielded.call(score_fixture(name).to_s)
    end
    stub_method(Vulnerabilities::Download, :open, open) { block.call(downloaded) }
  end

  def provider(key) = ScoreProvider.all_providers.find { |candidate| candidate.key == key }

  def custom_provider(**settings)
    ScoreProvider.create!(key: "custom-test", kind: "custom", name: "CVEFind", position: 9,
                          settings: { "url_template" => "https://www.cvefind.com/fr/cve/{cve}.html", "format" => "html", "delay_ms" => 200, "max_per_run" => 50 }.merge(settings.stringify_keys))
  end

  def vulnerable(server, cve, severity: "unknown", fixed: "2.0")
    server.server_vulnerabilities.create!(origin: "host", source: "debian", cve: cve, source_package: "openssh", packages: [ "openssh-server" ],
                                          installed_version: "1.0", fixed_version: fixed, severity: severity, distro_severity: severity)
  end
end
