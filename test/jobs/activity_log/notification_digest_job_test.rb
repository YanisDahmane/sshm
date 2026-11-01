require "test_helper"

class NotificationDigestJobTest < ActiveJob::TestCase
  include StubHelpers
  include SlackHelpers

  test "enqueues one job per enabled channel asking for the digest" do
    digest = create_channel(name: "#digest", daily_digest: true)
    create_channel(name: "#no-digest")
    create_channel(name: "#paused", daily_digest: true, enabled: false)

    assert_enqueued_with(job: NotificationDigestJob, args: [ digest ]) { NotificationDigestJob.perform_now }
    assert_enqueued_jobs 1, only: NotificationDigestJob
  end

  test "sends the digest and remembers it" do
    channel = create_channel(daily_digest: true)
    sent = []
    stub_method(Notifications::Slack, :post, ->(url, payload) { sent << payload[:text] }) { NotificationDigestJob.perform_now(channel) }

    assert_match(/\A\*Résumé Elio du .*\*\nParc :/, sent.sole)
    assert channel.reload.last_digest_at
  end

  test "remembers a failure and retries" do
    channel = create_channel(daily_digest: true)
    stub_method(Notifications::Slack, :post, ->(*) { raise Notifications::DeliveryError, "Slack a répondu 500" }) do
      assert_enqueued_jobs(1, only: NotificationDigestJob) { NotificationDigestJob.perform_now(channel) }
    end
    assert_equal "Slack a répondu 500", channel.reload.last_error
  end

  test "runs every morning" do
    recurring = YAML.load_file(Rails.root.join("config/recurring.yml"), aliases: true)
    assert_equal({ "class" => "NotificationDigestJob", "schedule" => "every day at 8am" }, recurring.dig("production", "notification_digests"))
  end
end
