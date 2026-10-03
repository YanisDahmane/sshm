require "test_helper"

class NotificationChannelTest < ActiveSupport::TestCase
  include SlackHelpers

  test "is valid with a name, a Slack webhook and known activity kinds" do
    channel = NotificationChannel.new(name: " #ops   alerts ", webhook_url: " #{WEBHOOK} ", activity_kinds: [ "key_added", "", "key_added" ])

    assert channel.valid?
    assert_equal "#ops alerts", channel.name
    assert_equal WEBHOOK, channel.webhook_url
    assert_equal [ "key_added" ], channel.activity_kinds
    assert channel.enabled?
    assert_not channel.mention_channel
  end

  test "only accepts Slack incoming webhooks" do
    [ "http://hooks.slack.com/services/T/B/X", "https://evil.example/services/T/B/X", "https://hooks.slack.com.evil.example/services/X",
      "https://hooks.slack.com/services/X?redirect=evil", "not a url" ].each do |url|
      channel = NotificationChannel.new(name: "x", webhook_url: url)
      assert_not channel.valid?, "#{url} should be rejected"
      assert channel.errors.key?(:webhook_url)
    end
  end

  test "requires a unique name and a webhook" do
    create_channel
    channel = NotificationChannel.new(name: "#OPS")
    assert_not channel.valid?
    assert channel.errors.of_kind?(:name, :taken)
    assert channel.errors.of_kind?(:webhook_url, :blank)
  end

  test "rejects unknown activity kinds" do
    channel = NotificationChannel.new(name: "x", webhook_url: WEBHOOK, activity_kinds: [ "key_added", "nope" ])
    assert_not channel.valid?
    assert channel.errors.key?(:activity_kinds)
  end

  test "the webhook is encrypted at rest and masked in the UI" do
    channel = create_channel

    raw = NotificationChannel.connection.select_value("SELECT webhook_url FROM notification_channels WHERE id = #{channel.id}")
    assert_not_includes raw, "hooks.slack.com"
    assert_equal "https://hooks.slack.com/services/T000…", channel.masked_webhook_url
  end

  test "subscribed_to lists the enabled channels receiving a kind" do
    ops = create_channel
    create_channel(name: "#paused", enabled: false)
    create_channel(name: "#keys", activity_kinds: %w[key_added])

    assert_equal [ ops ], NotificationChannel.subscribed_to(:ssh_access_lost).to_a
    assert ops.subscribed_to?("unknown_key_detected")
    assert_not ops.subscribed_to?(:key_added)
  end

  test "record_delivery! remembers the last success or error" do
    channel = create_channel

    channel.record_delivery!(error: "boom")
    assert_equal "boom", channel.reload.last_error

    channel.record_delivery!
    assert_nil channel.reload.last_error
    assert_not_nil channel.last_delivered_at
  end
end
