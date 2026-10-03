require "net/http"

# Sends messages to a Slack incoming webhook.
class SlackNotifier
  class DeliveryError < StandardError; end

  SEVERITY_EMOJIS = { info: ":information_source:", warning: ":warning:", critical: ":rotating_light:" }.freeze
  TIMEOUT = 5 # seconds

  def self.deliver(channel, activity)
    post(channel.webhook_url, activity_payload(activity, mention: channel.mention_channel))
  end

  def self.deliver_test(channel)
    text = "#{"<!channel> " if channel.mention_channel}:white_check_mark: Test SSHM : le canal « #{escape(channel.name)} » reçoit bien les notifications."
    post(channel.webhook_url, { text: text })
  end

  def self.activity_payload(activity, mention: false)
    emoji = SEVERITY_EMOJIS.fetch(activity.severity)
    title = "#{"<!channel> " if mention}#{emoji} *#{escape(activity.label)}*"
    context = [ "Par #{escape(activity.author_name)}", activity.server_name && "Serveur : #{escape(activity.server_name)}",
                activity.unix_user && "Compte : #{escape(activity.unix_user)}" ].compact.join(" · ")

    {
      text: "#{title}\n#{escape(activity.summary)}",
      blocks: [
        { type: "section", text: { type: "mrkdwn", text: "#{title}\n#{escape(activity.summary)}" } },
        { type: "context", elements: [ { type: "mrkdwn", text: context } ] }
      ]
    }
  end

  # Slack control characters: text coming from servers (key comments…) must
  # not be able to inject mentions (<!channel>) or links (<url|label>).
  def self.escape(text)
    text.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;")
  end

  def self.post(url, payload)
    uri = URI(url)
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: TIMEOUT, read_timeout: TIMEOUT) do |http|
      http.post(uri.request_uri, payload.to_json, "Content-Type" => "application/json")
    end
    raise DeliveryError, "Slack a répondu #{response.code} : #{response.body.to_s.truncate(200)}" unless response.is_a?(Net::HTTPSuccess)

    response
  rescue SocketError, SystemCallError, IOError, Timeout::Error, OpenSSL::SSL::SSLError, Net::HTTPBadResponse => e
    raise DeliveryError, "Impossible de joindre Slack (#{e.class}: #{e.message})"
  end
end
