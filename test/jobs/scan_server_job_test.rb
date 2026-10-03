require "test_helper"

class ScanServerJobTest < ActiveJob::TestCase
  include StubHelpers

  test "scans the server" do
    scanned = []
    stub_method(ServerScan, :call, ->(server, **) { scanned << server }) { ScanServerJob.perform_now(servers(:web)) }
    assert_equal [ servers(:web) ], scanned
  end
end
