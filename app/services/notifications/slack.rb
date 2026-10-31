# Sends messages to a Slack incoming webhook.
class Notifications::Slack
  SEVERITY_EMOJIS = { info: ":information_source:", warning: ":warning:", critical: ":rotating_light:" }.freeze

  def self.deliver(channel, activity)
    post(channel.webhook_url, activity_payload(activity, mention: channel.mention_channel))
  end

  def self.deliver_test(channel)
    text = "#{"<!channel> " if channel.mention_channel}:white_check_mark: Test Elio : le canal « #{escape(channel.name)} » reçoit bien les notifications."
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

  def self.deliver_digest(channel, digest)
    post(channel.webhook_url, { text: "*#{escape(digest.title)}*\n#{digest.lines.map { |line| escape(line) }.join("\n")}" })
  end

  def self.post(url, payload)
    Notifications::Http.post(url, payload.to_json, service: "Slack")
  end
end
