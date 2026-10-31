require "openssl"

# Sends events to a generic HTTPS webhook as JSON. Each request is signed:
# X-Elio-Signature: sha256=<hex HMAC SHA-256 of the raw body, with the
# channel's signing secret>, so the receiver can check it comes from Elio.
class Notifications::Webhook
  def self.deliver(channel, activity)
    post(channel, "activity", {
      kind: activity.kind, label: activity.label, category: activity.category, severity: activity.severity, summary: activity.summary,
      server: activity.server_name, unix_user: activity.unix_user, author: activity.user&.email, created_at: activity.created_at.iso8601
    })
  end

  def self.deliver_test(channel)
    post(channel, "test", { message: "Le canal « #{channel.name} » reçoit bien les notifications." })
  end

  def self.deliver_digest(channel, digest)
    post(channel, "digest", { title: digest.title, lines: digest.lines, from: digest.from.iso8601, to: digest.to.iso8601, counts: digest.counts })
  end

  def self.post(channel, event, data)
    body = { event: event, sent_at: Time.current.iso8601, data: data }.to_json
    Notifications::Http.post(channel.webhook_url, body, service: "Le webhook",
                          headers: { "X-Elio-Event" => event, "X-Elio-Delivery" => SecureRandom.uuid, "X-Elio-Signature" => "sha256=#{signature(channel, body)}" })
  end

  def self.signature(channel, body) = OpenSSL::HMAC.hexdigest("SHA256", channel.signing_secret, body)
end
