require "test_helper"

class BoundedParallelTest < ActiveSupport::TestCase
  def track_concurrency
    running = Concurrent::AtomicFixnum.new
    peak = Concurrent::AtomicFixnum.new
    work = lambda do |value|
      peak.update { |current| [ current, running.increment ].max }
      sleep 0.02
      running.decrement
      value * 2
    end
    [ work, peak ]
  end

  test "returns the results in the items' order" do
    assert_equal [ 6, 2, 4 ], BoundedParallel.map([ 3, 1, 2 ], limit: 3) { |value| sleep(value / 100.0); value * 2 }
  end

  test "never runs more than the limit at once, and does run in parallel" do
    work, peak = track_concurrency

    assert_equal (1..10).map { |value| value * 2 }, BoundedParallel.map(1..10, limit: 3, &work)
    assert_equal 3, peak.value
  end

  test "runs inline with a limit of 1 or a single item" do
    work, peak = track_concurrency

    BoundedParallel.map([ 1, 2, 3 ], limit: 1, &work)
    assert_equal 1, peak.value
    assert_equal [ Thread.current ], BoundedParallel.map([ :one ]) { Thread.current }
  end

  test "an error does not stop the other items, and is raised at the end" do
    done = Concurrent::Array.new

    error = assert_raises(RuntimeError) do
      BoundedParallel.map([ 1, 2, 3, 4 ], limit: 2) do |value|
        raise "boom #{value}" if value == 1
        done << value
      end
    end

    assert_equal "boom 1", error.message
    assert_equal [ 2, 3, 4 ], done.sort
  end

  test "the block can use Active Record" do
    names = BoundedParallel.map(Server.order(:name).pluck(:id), limit: 2) { |id| Server.find(id).name }

    assert_equal %w[Backup Database Web], names
  end

  test "an empty list gives an empty list" do
    assert_equal [], BoundedParallel.map([]) { flunk }
    assert_nil BoundedParallel.each([ 1 ]) { }
  end
end
