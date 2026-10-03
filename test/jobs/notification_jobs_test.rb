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

  test "DeliverNotificationJob sends the activity and records the delivery" do
    channel = create_channel
    activity = Activity.record!(:ssh_access_lost, server: servers(:web))
    delivered = []

    stub_method(SlackNotifier, :deliver, ->(c, a) { delivered << [ c, a ] }) { DeliverNotificationJob.perform_now(channel, activity) }

    assert_equal [ [ channel, activity ] ], delivered
    assert_not_nil channel.reload.last_delivered_at
  end

  test "DeliverNotificationJob skips a channel paused or unsubscribed meanwhile" do
    channel = create_channel
    activity = Activity.record!(:ssh_access_lost, server: servers(:web))
    channel.update!(activity_kinds: %w[key_added])

    stub_method(SlackNotifier, :deliver, ->(*) { flunk "should not deliver" }) { DeliverNotificationJob.perform_now(channel, activity) }
  end

  test "DeliverNotificationJob records the error and retries" do
    channel = create_channel
    activity = Activity.record!(:ssh_access_lost, server: servers(:web))

    stub_method(SlackNotifier, :deliver, ->(*) { raise SlackNotifier::DeliveryError, "Slack a répondu 500" }) do
      DeliverNotificationJob.perform_now(channel, activity)
    end

    assert_equal "Slack a répondu 500", channel.reload.last_error
    assert_enqueued_with(job: DeliverNotificationJob, args: [ channel, activity ])
  end
end
