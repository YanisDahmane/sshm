require "test_helper"

class Inventory::DebianVersionTest < ActiveSupport::TestCase
  def assert_older(left, right)
    assert Inventory::DebianVersion.older?(left, right), "#{left} < #{right}"
    assert_equal 1, Inventory::DebianVersion.compare(right, left), "#{right} > #{left}"
  end

  test "compares like dpkg --compare-versions" do
    assert_older "1.0", "1.1"
    assert_older "1.9", "1.10"
    assert_older "1.0~rc1", "1.0"
    assert_older "1.0~~", "1.0~"
    assert_older "1.0", "1.0a"
    assert_older "1.0a", "1.0+"
    assert_older "1.0-1", "1.0-2"
    assert_older "1.0-9", "1.0-10"
    assert_older "2.0", "1:0.1"
    assert_older "3.0.14-1~deb12u1", "3.0.15-1~deb12u1"
    assert_older "3.0.15-1~deb12u1", "3.0.15-1"
    assert_older "2.36-9+deb12u7", "2.36-9+deb12u8"
    assert_older "1:9.2p1-2+deb12u2", "1:9.2p1-2+deb12u3"
    assert_older "5.15.0-91.101", "5.15.0-105.115"
    assert_older "1.2.13.dfsg-1", "1.2.13.dfsg-1+b1"
    assert_older "7.88.1-10+deb12u5", "7.88.1-10+deb12u12"
  end

  test "equal versions" do
    assert_equal 0, Inventory::DebianVersion.compare("1.0-1", "1.0-1")
    assert_equal 0, Inventory::DebianVersion.compare("0:1.0", "1.0")
    assert_equal 0, Inventory::DebianVersion.compare("1.0", "1.0-")
  end

  test "the revision is after the last hyphen" do
    assert_equal [ 0, "1.2-3", "4" ], Inventory::DebianVersion.split("1.2-3-4")
    assert_equal [ 2, "1.0", "" ], Inventory::DebianVersion.split("2:1.0")
  end
end
