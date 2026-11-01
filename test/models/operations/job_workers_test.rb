require "test_helper"

class JobWorkersTest < ActiveSupport::TestCase
  test "unknown with another queue adapter (the test adapter)" do
    assert_nil JobWorkers.running?
  end
end
