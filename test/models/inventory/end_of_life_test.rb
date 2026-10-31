require "test_helper"

class Inventory::EndOfLifeTest < ActiveSupport::TestCase
  TODAY = Date.new(2026, 10, 31)

  def status(id, version) = Inventory::EndOfLife.status(id, version, today: TODAY)

  test "supported, ending soon, ended or unknown" do
    assert_equal :supported, status("debian", "12").state
    assert_equal Date.new(2028, 6, 30), status("debian", "12").date
    assert Inventory::EndOfLife.status("debian", "12", today: Date.new(2028, 3, 1)).soon?
    assert status("ubuntu", "25.10").ended?
    assert status("debian", "10").ended?
    assert status("ubuntu", "20.04").ended?
    assert_not status("alpine", "3.20").known?
    assert_not status("debian", nil).known?
  end

  test "Debian point releases follow their major version" do
    assert_equal status("debian", "12"), status("debian", "12.7")
  end

  test "Debian 11 ends in August 2026" do
    assert status("debian", "11").ended?
    assert Inventory::EndOfLife.status("debian", "11", today: Date.new(2026, 5, 1)).soon?
  end
end
