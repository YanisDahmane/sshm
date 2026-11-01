require "test_helper"

class NotificationJobsTest < ActiveJob::TestCase
  include SlackHelpers
  include StubHelpers

  test "creating an activity enqueues its notification" do
    activity = Activity.record!(:key_added, server: servers(:web))
    assert_enqueued_with(job: NotifyActivityJob, args: [ activity ])
  end

  test "NotifyActivityJob delivers to each enabled channel subscribed to the kind" do
    ops = create_channel
    security = create_channel(name: "#security", activity_kinds: %w[unknown_key_detected])
    create_channel(name: "#paused", enabled: false)
    create_channel(name: "#keys", activity_kinds: %w[key_added])
    activity = Activity.record!(:unknown_key_detected, server: servers(:web))

    NotifyActivityJob.perform_now(activity)

    assert_enqueued_jobs 2, only: DeliverNotificationJob
    assert_enqueued_with(job: DeliverNotificationJob, args: [ ops, activity ])
    assert_enqueued_with(job: DeliverNotificationJob, args: [ security, activity ])
  end

  test "a channel's messages are written in its language, else the instance's" do
    english = create_channel(locale: "en", activity_kinds: %w[server_unreachable])
    french = create_channel(name: "#fr", activity_kinds: %w[server_unreachable])
    activity = Activity.record!(:server_unreachable, server: servers(:web))
    texts = []

    stub_method(Notifications::Slack, :post, ->(_channel, payload) { texts << payload.to_json }) do
      DeliverNotificationJob.perform_now(english, activity)
      DeliverNotificationJob.perform_now(french, activity)
    end

    assert_match "Server unreachable", texts.first
    assert_match "“Web” no longer answers", texts.first
    assert_match "Serveur injoignable", texts.last
    assert_match "« Web » ne répond plus", texts.last
  end

  test "DeliverNotificationJob sends the activity and records the delivery" do
    channel = create_channel
    activity = Activity.record!(:ssh_access_lost, server: servers(:web))
    delivered = []

    stub_method(Notifications::Slack, :deliver, ->(c, a) { delivered << [ c, a ] }) { DeliverNotificationJob.perform_now(channel, activity) }

    assert_equal [ [ channel, activity ] ], delivered
    assert_not_nil channel.reload.last_delivered_at
  end

  test "DeliverNotificationJob skips a channel paused or unsubscribed meanwhile" do
    channel = create_channel
    activity = Activity.record!(:ssh_access_lost, server: servers(:web))
    channel.update!(activity_kinds: %w[key_added])

    stub_method(Notifications::Slack, :deliver, ->(*) { flunk "should not deliver" }) { DeliverNotificationJob.perform_now(channel, activity) }
  end

  test "DeliverNotificationJob records the error and retries" do
    channel = create_channel
    activity = Activity.record!(:ssh_access_lost, server: servers(:web))

    stub_method(Notifications::Slack, :deliver, ->(*) { raise Notifications::DeliveryError, "Slack a répondu 500" }) do
      DeliverNotificationJob.perform_now(channel, activity)
    end

    assert_equal "Slack a répondu 500", channel.reload.last_error
    assert_enqueued_with(job: DeliverNotificationJob, args: [ channel, activity ])
  end
end
