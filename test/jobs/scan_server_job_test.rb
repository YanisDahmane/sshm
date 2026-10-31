require "test_helper"

class ScanServerJobTest < ActiveJob::TestCase
  include StubHelpers

  test "scans the server" do
    scanned = []
    stub_method(ServerScan, :call, ->(server, **) { scanned << server }) { ScanServerJob.perform_now(servers(:web)) }
    assert_equal [ servers(:web) ], scanned
  end

  test "reports to its task item" do
    task = BackgroundTask.enqueue!(kind: "keys_scan", label: "Scan", servers: [ servers(:web) ], user: users(:one))
    item = task.items.sole

    stub_method(ServerScan, :call, ServerScan::Result.new(error_title: "Connexion impossible")) { ScanServerJob.perform_now(servers(:web), task_item: item) }

    assert_equal [ "failed", "Connexion impossible" ], [ item.reload.status, item.message ]
    assert_equal "failed", task.reload.status
  end
end
