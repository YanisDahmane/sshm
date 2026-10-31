require "test_helper"

class Inventory::Collectors::PackagesTest < ActiveSupport::TestCase
  Collector = Inventory::Collectors::Packages

  def output(name) = file_fixture("inventory/packages/#{name}.txt").read

  def collect(name, sudo: true, docker: FakeSsh::Response.new(output(:docker_images), "", 0))
    known_hosts = Rails.root.join("tmp", "test", "packages-#{SecureRandom.hex(4)}", "known_hosts")
    main = FakeSsh::Response.new(output(name), "", 0)
    fake = FakeSsh.new(responses: { "sudo -n true" => FakeSsh::Response.new("", "", sudo ? 0 : 1) },
                       handler: ->(command) { command.start_with?("sh -c") ? main : (docker if command.include?("docker image ls")) })
    outcome = SshConnection.open(servers(:web), transport: fake, known_hosts_file: known_hosts) { |ssh| Collector.new(ssh).collect }
    [ outcome, fake.commands ]
  ensure
    FileUtils.rm_rf(known_hosts.dirname)
  end

  test "lists the installed dpkg packages with their updates, and the Docker images through sudo" do
    outcome, commands = collect(:debian12)

    assert_equal "ok", outcome.status
    packages = outcome.data["packages"]
    dpkg = packages.select { |package| package["manager"] == "dpkg" }
    assert_equal %w[adduser curl libssl3 libssl3 linux-image-amd64 openssl postgresql-15], dpkg.map { |package| package["name"] }
    assert_equal({ "manager" => "dpkg", "name" => "openssl", "version" => "3.0.14-1~deb12u1", "arch" => "amd64",
                   "available_version" => "3.0.15-1~deb12u1", "security" => true }, dpkg.find { |package| package["name"] == "openssl" })
    assert_equal [ "7.88.1-10+deb12u8", false ], dpkg.find { |package| package["name"] == "curl" }.values_at("available_version", "security")
    assert_equal [ [ "nginx", "1.27-alpine" ], [ "postgres", "16" ], [ "ghcr.io/acme/api", "fedcba987654" ] ],
                 packages.select { |package| package["manager"] == "docker" }.map { |package| package.values_at("name", "version") }
    assert_equal({ "dpkg" => 7, "docker" => 3 }, outcome.data["by_manager"])
    assert_equal [ 10, 4, 3 ], outcome.data.values_at("total", "upgradable", "security")
    assert_includes commands, "sudo -n #{Collector::DOCKER_IMAGES}"
  end

  test "Docker images that cannot be read make the collection partial" do
    outcome, = collect(:debian12, sudo: false, docker: FakeSsh::Response.new("", "permission denied while trying to connect to the Docker daemon socket", 1))

    assert_equal "partial", outcome.status
    assert_match "Images Docker illisibles : permission denied", outcome.message
    assert_equal 7, outcome.data["total"]
  end

  test "Ubuntu: snaps and security updates from -security suites" do
    outcome, commands = collect(:ubuntu2404)

    assert_equal [ [ "snap", "core22", "20240904" ], [ "snap", "lxd", "5.21.2" ] ],
                 outcome.data["packages"].select { |package| package["manager"] == "snap" }.map { |package| package.values_at("manager", "name", "version") }
    assert outcome.data["packages"].find { |package| package["name"] == "snapd" }["security"]
    assert_not commands.any? { |command| command.include?("docker image ls") }
  end

  test "a system without dpkg nor snap is unsupported" do
    outcome, = collect(:none)
    assert_equal [ "unsupported", "Ni dpkg ni snap sur ce système" ], [ outcome.status, outcome.message ]
  end

  test "the snapshot keeps the counts, not the list" do
    data = Collector.summarize([ { "manager" => "dpkg", "name" => "a" } ])
    assert_equal({ "total" => 1, "by_manager" => { "dpkg" => 1 }, "upgradable" => 0, "security" => 0 }, Collector.snapshot_data(data))
  end

  test "records the list, replaces it and logs the changes after the first time" do
    server = servers(:web)
    first = Collector.summarize([ { "manager" => "dpkg", "name" => "curl", "version" => "1", "arch" => "amd64" },
                                  { "manager" => "dpkg", "name" => "vim", "version" => "9", "arch" => "amd64" } ])
    assert_no_difference("Activity.count") { Collector.record(server, first, Time.current) }
    assert_equal %w[curl vim], server.packages.order(:name).pluck(:name)

    second = Collector.summarize([ { "manager" => "dpkg", "name" => "curl", "version" => "2", "arch" => "amd64", "available_version" => "3", "security" => true },
                                   { "manager" => "dpkg", "name" => "htop", "version" => "3", "arch" => "amd64" } ])
    Collector.record(server, second, Time.current)

    assert_equal [ [ "curl", "2", "3", true ], [ "htop", "3", nil, false ] ],
                 server.packages.order(:name).pluck(:name, :version, :available_version, :security)
    activity = Activity.of_kind(:packages_changed).sole
    assert_equal "Paquets de « Web » : 1 installé, 1 mis à jour, 1 supprimé (curl, htop, vim)", activity.summary
  end

  test "warns when security updates appear" do
    assert_equal [ { kind: :security_updates_available, data: { count: 3 } } ], Collector.changes({ "security" => 0 }, { "security" => 3 })
    assert_empty Collector.changes({ "security" => 2 }, { "security" => 3 })
    assert_empty Collector.changes({ "security" => 2 }, { "security" => 0 })
  end
end
