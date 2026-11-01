require "nokogiri"

# A provider set up in the settings: GET of an URL template ({cve}), then the
# score read with a JSON path ("cvss3.cvss3_base_score", "metrics.0.score")
# or, on an HTML page, a CSS selector and / or a regex (first capture group).
# Its pace (delay_ms, max_per_run) protects the site; check its terms of use.
class Vulnerabilities::Scores::Custom < Vulnerabilities::Scores::Base
  REGEX_TIMEOUT = 1 # second

  def fetch(cves) = fetch_each(cves)

  def lookup(cve)
    body = get(url_for(provider.setting("url_template"), cve), accept: provider.setting("format") == "json" ? "application/json" : "text/html") or return nil
    text = provider.setting("format") == "json" ? json_value(body) : html_value(body)
    score = cvss(text.to_s[/\d+(?:[.,]\d+)?/])
    Score.new(score: score) if score
  end

  private

  def json_value(body)
    provider.setting("json_path").split(".").reduce(JSON.parse(body)) do |value, part|
      case value
      when Array then value[Integer(part, exception: false) || 0]
      when Hash then value[part]
      end
    end
  rescue JSON::ParserError
    raise Integrations::Error, "#{provider.name} : la réponse n'est pas du JSON"
  end

  def html_value(body)
    text = body
    if (selector = provider.setting("css_selector"))
      node = Nokogiri::HTML(body).at_css(selector) or return nil
      text = node.text
    end
    return text.strip unless (regex = provider.setting("regex"))

    Regexp.new(regex, timeout: REGEX_TIMEOUT).match(text)&.then { |match| match[1] || match[0] }
  rescue Regexp::TimeoutError
    raise Integrations::Error, "#{provider.name} : regex trop lente"
  end
end
