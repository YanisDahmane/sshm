require "test_helper"

class Inventory::HealthSampleTest < ActiveSupport::TestCase
  test "purges the points older than 30 days" do
    now = Time.current
    old = servers(:web).health_samples.create!(collected_at: now - 31.days, load_percent: 10)
    kept = servers(:web).health_samples.create!(collected_at: now - 29.days, load_percent: 10)

    assert_equal 1, Inventory::HealthSample.purge!(now: now)
    assert_equal [ kept ], Inventory::HealthSample.all.to_a
    assert_raises(ActiveRecord::RecordNotFound) { old.reload }
  end

  test "since lists the recent points in order, and the history goes with its server" do
    second = servers(:web).health_samples.create!(collected_at: 1.hour.ago)
    first = servers(:web).health_samples.create!(collected_at: 2.hours.ago)
    servers(:web).health_samples.create!(collected_at: 2.days.ago)

    assert_equal [ first, second ], servers(:web).health_samples.since(1.day.ago).to_a
    assert_difference("Inventory::HealthSample.count", -3) { servers(:web).destroy! }
  end

  test "the purge job runs the purge" do
    servers(:web).health_samples.create!(collected_at: 40.days.ago)
    assert_difference("Inventory::HealthSample.count", -1) { Inventory::PurgeHealthSamplesJob.perform_now }
  end
end
