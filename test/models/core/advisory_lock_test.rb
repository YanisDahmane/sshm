require "test_helper"

class AdvisoryLockTest < ActiveSupport::TestCase
  include AdvisoryLockHelpers

  test "try runs the block and releases the lock" do
    assert_equal :done, AdvisoryLock.try("test:a") { :done }
    assert_equal :again, AdvisoryLock.try("test:a") { :again }
  end

  test "try skips the block while another connection holds the lock" do
    with_lock_held_elsewhere("test:a") do
      ran = false
      assert AdvisoryLock.try("test:a") { ran = true }.equal?(AdvisoryLock::HELD)
      assert_not ran
      assert_equal :other, AdvisoryLock.try("test:b") { :other }
    end
    assert_equal :free, AdvisoryLock.try("test:a") { :free }
  end

  test "the lock is released when the block raises" do
    assert_raises(RuntimeError) { AdvisoryLock.hold("test:a") { raise "boom" } }
    assert_equal :free, AdvisoryLock.try("test:a") { :free }
  end

  test "keys depend on the database" do
    connection = ActiveRecord::Base.connection
    assert_not_equal AdvisoryLock.key(connection, "test:a"), AdvisoryLock.key(connection, "test:b")
    assert_equal Zlib.crc32("#{connection.current_database}:test:a"), AdvisoryLock.key(connection, "test:a")
  end
end
