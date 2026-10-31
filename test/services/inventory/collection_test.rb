require "test_helper"

# Fake collectors: each reads one command over the (fake) SSH session.
class FakeReleaseCollector < Inventory::Collector
  def collect
    ok({ "release" => run("cat /etc/release").stdout.strip })
  end

  def self.changes(previous, data)
    return [] if previous["release"] == data["release"]

    [ { kind: :automation_run, data: { automation_label: "Système", result: "#{previous["release"]} → #{data["release"]}" } } ]
  end
end

class FakeListeningCollector < Inventory::Collector
  def collect
    output = run("ss -tlnp", privileged: true).stdout
    privileged? ? ok({ "ports" => output.split }) : partial({ "ports" => output.split }, "Processus inconnus sans accès root")
  end
end

class FakeBrokenCollector < Inventory::Collector
  def collect = raise(NoMethodError, "bug in the parser")
end

class FakeFailingCollector < Inventory::Collector
  def collect = raise(Inventory::Collector::Error, "dpkg introuvable")
end

class FakeHangingCollector < Inventory::Collector
  def collect = ok({ "out" => run("sleep 99", timeout: 0.1).stdout })
end

class Inventory::CollectionTest < ActiveSupport::TestCase
  include InventoryHelpers
  include StubHelpers

  REGISTRY = { "release" => "FakeReleaseCollector", "listening" => "FakeListeningCollector" }.freeze

  setup do
    @server = servers(:web) # deploy, not root
    @known_hosts = Rails.root.join("tmp", "test", "inventory-#{SecureRandom.hex(4)}", "known_hosts")
  end

  teardown { FileUtils.rm_rf(@known_hosts.dirname) }

  def responses(release: "Debian 12", sudo: true, extra: {})
    {
      "sudo -n true" => FakeSsh::Response.new("", sudo ? "" : "sudo: a password is required\n", sudo ? 0 : 1),
      "cat /etc/release" => FakeSsh::Response.new("#{release}\n", "", 0),
      "sudo -n ss -tlnp" => FakeSsh::Response.new("22 443", "", 0),
      "ss -tlnp" => FakeSsh::Response.new("22 443", "", 0)
    }.merge(extra)
  end

  def collect(fake, registry: REGISTRY, **options)
    with_collectors(registry) do
      Inventory::Collection.call(@server, transport: fake, known_hosts_file: @known_hosts, **options)
    end
  end

  test "collects every category in one session and records them" do
    fake = FakeSsh.new(responses: responses)

    outcomes = collect(fake)

    assert_equal %w[release listening], outcomes.keys
    assert_equal 1, fake.sessions.size
    assert_equal [ "sudo -n true", "cat /etc/release", "sudo -n ss -tlnp" ], fake.commands
    release = @server.inventory_snapshots.of_category(:release).sole
    assert_equal [ "ok", { "release" => "Debian 12" }, true ], [ release.status, release.data, release.privileged ]
    assert_in_delta Time.current, release.collected_at, 2
    assert_equal({ "ports" => %w[22 443] }, @server.inventory("listening").data)
    @server.reload
    assert_equal [ "sudo", true ], [ @server.privilege, @server.ssh_ok ]
    assert_in_delta Time.current, @server.inventoried_at, 2
  end

  test "without root access, privileged commands run as the user and the category is partial" do
    outcomes = collect(FakeSsh.new(responses: responses(sudo: false)))

    assert_equal "partial", outcomes["listening"].status
    snapshot = @server.inventory("listening")
    assert_equal [ "partial", "Processus inconnus sans accès root", false ], [ snapshot.status, snapshot.message, snapshot.privileged ]
    assert_equal "none", @server.reload.privilege
  end

  test "only the requested categories are collected" do
    fake = FakeSsh.new(responses: responses)

    collect(fake, categories: [ :release ])

    assert_equal %w[release], @server.inventory_snapshots.pluck(:category)
    assert_not_includes fake.commands, "sudo -n ss -tlnp"
  end

  test "a failing, a buggy or a hanging collector only fails its own category" do
    registry = REGISTRY.merge("failing" => "FakeFailingCollector", "broken" => "FakeBrokenCollector")
    reported = []
    stub_method(Rails.error, :report, ->(error, **) { reported << error }) do
      collect(FakeSsh.new(responses: responses), registry: registry)
    end

    assert_equal %w[ok ok error error], %w[release listening failing broken].map { |category| @server.inventory(category).status }
    assert_equal "dpkg introuvable", @server.inventory("failing").message
    assert_equal "Erreur interne pendant la collecte (NoMethodError)", @server.inventory("broken").message
    assert_equal [ NoMethodError ], reported.map(&:class)
  end

  test "a command past its time limit fails its category and the ones after it" do
    registry = { "hanging" => "FakeHangingCollector", "release" => "FakeReleaseCollector" }
    fake = FakeSsh.new(responses: responses(extra: { "sleep 99" => FakeSsh::Response.new("", "", 0, true) }))

    outcomes = collect(fake, registry: registry)

    assert_equal %w[error error], outcomes.values.map(&:status)
    assert_match "n'a pas répondu en 0.1 s", outcomes["hanging"].message
    assert_match "fermée après un délai dépassé", outcomes["release"].message
  end

  test "a failed collection keeps the previous data" do
    collect(FakeSsh.new(responses: responses))
    collected_at = @server.inventory("release").collected_at

    travel 1.hour do
      collect(FakeSsh.new(error: Errno::ECONNREFUSED.new("connect(2)")))
    end

    snapshot = @server.inventory_snapshots.reload.of_category(:release).sole
    assert_equal [ "error", { "release" => "Debian 12" } ], [ snapshot.status, snapshot.data ]
    assert_match(/\AConnexion impossible — /, snapshot.message)
    assert_equal collected_at, snapshot.collected_at
    assert snapshot.checked_at > collected_at
  end

  test "a refused key fails every category and records the SSH status" do
    @server.update_columns(ssh_ok: true)

    outcomes = collect(FakeSsh.new(error: Net::SSH::AuthenticationFailed.new("deploy")))

    assert_equal %w[error error], outcomes.values.map(&:status)
    assert_equal false, @server.reload.ssh_ok
    assert_nil @server.inventory("release").collected_at
  end

  test "logs what changed, but not on the first collection" do
    assert_no_difference("Activity.count") { collect(FakeSsh.new(responses: responses)) }
    assert_no_difference("Activity.count") { collect(FakeSsh.new(responses: responses)) }

    collect(FakeSsh.new(responses: responses(release: "Debian 13")))

    activity = Activity.of_kind(:automation_run).sole
    assert_equal [ @server, nil, "Système : Debian 12 → Debian 13" ], [ activity.server, activity.user, activity.summary ]
  end

  test "registered categories come from the collector classes" do
    with_collectors(REGISTRY) do
      assert_equal %w[release listening], Inventory::Collector.categories
      assert_equal FakeReleaseCollector, Inventory::Collector.for(:release)
      assert_equal [], Inventory::Collector.changes({}, {})
    end
  end

  test "the system collector summarises the OS on the server" do
    os_output = file_fixture("inventory/os/debian12.txt").read
    fake = FakeSsh.new(handler: ->(command) { FakeSsh::Response.new(os_output, "", 0) if command.start_with?("sh -c") },
                       responses: { "sudo -n true" => FakeSsh::Response.new("", "", 0) })

    collect(fake, registry: Inventory::Collector::CATEGORIES)

    @server.reload
    assert_equal [ "Debian GNU/Linux 12 (bookworm)", "debian", "12" ], [ @server.os_name, @server.os_id, @server.os_version ]
    assert_equal "kvm", @server.inventory("os").data["virtualization"]
  end
end
