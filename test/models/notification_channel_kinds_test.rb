require "test_helper"

class NotificationChannelKindsTest < ActiveSupport::TestCase
  def build(**attributes) = NotificationChannel.new({ name: "Canal", activity_kinds: %w[server_unreachable] }.merge(attributes))

  test "each kind checks its destination" do
    assert build(kind: "discord", webhook_url: "https://discord.com/api/webhooks/123456/abc_DEF-ghi").valid?
    assert_not build(kind: "discord", webhook_url: "https://hooks.slack.com/services/T/B/X").valid?
    assert build(kind: "webhook", webhook_url: "https://hooks.acme.fr/elio").valid?
    assert_not build(kind: "webhook", webhook_url: "http://hooks.acme.fr/elio").valid?
    assert_not build(kind: "webhook", webhook_url: "").valid?
    assert build(kind: "email", recipients: "Ops@Acme.fr; alice@acme.fr  ops@acme.fr").tap(&:validate).then { |channel| channel.valid? && channel.recipients == "ops@acme.fr, alice@acme.fr" }

    invalid = build(kind: "email", recipients: "ops@acme.fr, nope")
    assert_not invalid.valid?
    assert_includes invalid.errors[:recipients].sole, "nope"
    assert build(kind: "email", recipients: "").tap(&:validate).errors.added?(:recipients, :blank)
    assert_not build(kind: "email", recipients: (1..21).map { |i| "u#{i}@acme.fr" }.join(",")).valid?
    assert_not build(kind: "sms", webhook_url: "https://x").valid?
  end

  test "a webhook channel gets a signing secret, stored encrypted" do
    channel = build(kind: "webhook", webhook_url: "https://hooks.acme.fr/elio")
    channel.save!

    assert_match(/\A\h{64}\z/, channel.signing_secret)
    raw = NotificationChannel.connection.select_value("SELECT signing_secret FROM notification_channels WHERE id = #{channel.id}")
    assert_not_includes raw, channel.signing_secret
    assert_nil build(kind: "slack", webhook_url: SlackHelpers::WEBHOOK).tap(&:validate).signing_secret
  end

  test "labels, notifiers and masked destinations" do
    assert_equal [ "Discord", Notifications::Discord ], build(kind: "discord").then { |channel| [ channel.kind_label, channel.notifier ] }
    assert_equal Notifications::Email, build(kind: "email").notifier
    assert_equal "ops@acme.fr", build(kind: "email", recipients: "ops@acme.fr").tap(&:validate).masked_destination
    assert_equal "https://discord.com/api/webhook…", build(kind: "discord", webhook_url: "https://discord.com/api/webhooks/1/secret").masked_destination
    assert build(kind: "slack").mentions?
    assert_not build(kind: "webhook").mentions?
  end
end
