require "test_helper"

class Inventory::CollectorTest < ActiveSupport::TestCase
  class Echo < Inventory::Collector
    def collect = ok({ "out" => run("cat /big").stdout.size })
  end

  def connect(fake, &block)
    known_hosts = Rails.root.join("tmp", "test", "collector-#{SecureRandom.hex(4)}", "known_hosts")
    Ssh::Connection.open(servers(:web), transport: fake, known_hosts_file: known_hosts, &block)
  ensure
    FileUtils.rm_rf(known_hosts.dirname)
  end

  test "refuses an unreasonably large output" do
    huge = "x" * (Inventory::Collector::MAX_OUTPUT + 1)
    fake = FakeSsh.new(responses: { "cat /big" => FakeSsh::Response.new(huge, "", 0) })

    error = assert_raises(Inventory::Collector::Error) { connect(fake) { |ssh| Echo.new(ssh).collect } }
    assert_equal "Sortie trop volumineuse pour « cat /big »", error.message
  end

  test "outcomes carry a status, data and a message" do
    fake = FakeSsh.new(responses: { "cat /big" => FakeSsh::Response.new("abc", "", 0) })

    outcome = connect(fake) { |ssh| Echo.new(ssh).collect }

    assert_equal Inventory::Collector::Outcome.new(status: "ok", data: { "out" => 3 }, message: nil), outcome
  end

  test "the base class has no collect of its own" do
    assert_raises(NotImplementedError) { Inventory::Collector.new(nil).collect }
  end
end
