require "test_helper"

class Inventory::CollectJobTest < ActiveJob::TestCase
  include StubHelpers

  test "collects every category, or the given ones" do
    calls = []
    stub_method(Inventory::Collection, :call, ->(server, **options) { calls << [ server, options ] }) do
      Inventory::CollectJob.perform_now(servers(:web))
      Inventory::CollectJob.perform_now(servers(:web), %w[os])
    end

    assert_equal [ [ servers(:web), {} ], [ servers(:web), { categories: %w[os] } ] ], calls
  end
end
