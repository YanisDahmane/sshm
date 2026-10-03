require "test_helper"

class ExpireTemporaryAccessesJobTest < ActiveJob::TestCase
  include TemporaryAccessHelpers

  test "enqueues the expiry of every expired active access" do
    expired = create_temporary_access(expires_at: 1.minute.ago)
    create_temporary_access(profile: profiles(:alice), expires_at: 1.minute.from_now)
    create_temporary_access(profile: profiles(:alice), unix_user: "root", expires_at: 1.minute.ago).end!

    ExpireTemporaryAccessesJob.perform_now

    assert_enqueued_jobs 1, only: ExpireTemporaryAccessJob
    assert_enqueued_with(job: ExpireTemporaryAccessJob, args: [ expired ])
  end

  test "runs every minute in production" do
    recurring = YAML.load_file(Rails.root.join("config/recurring.yml"))["production"]["expire_temporary_accesses"]
    assert_equal({ "class" => "ExpireTemporaryAccessesJob", "schedule" => "every minute" }, recurring)
  end
end
