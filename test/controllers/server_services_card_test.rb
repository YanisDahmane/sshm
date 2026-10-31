require "test_helper"

class ServerServicesCardTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def collect(data, status: "ok", message: nil)
    servers(:web).inventory_snapshots.create!(category: "services", status: status, data: data, message: message, collected_at: Time.current, checked_at: Time.current)
  end

  def parsed
    units = Inventory::Collectors::Services.parse_units(file_fixture("inventory/services/debian12.txt").read.split("@@elio unit-files").first.sub("@@elio units\n", ""),
                                                        { "ssh.service" => "enabled" })
    containers = Inventory::Collectors::Services.parse_containers(file_fixture("inventory/services/docker_ps.txt").read)
    { "units" => units, "containers" => containers, "docker" => "ok" }
  end

  test "shows the failed units first, folds the inactive ones, and groups the containers by Compose project" do
    collect(parsed)
    sign_in users(:viewer)

    get server_path(servers(:web))

    assert_select "#server-services" do
      assert_select ".services-summary", text: /4 services actifs\s+· 1 en échec\s+· 2 inactifs\s+· 2\/3 conteneurs en cours/
      assert_select ".systemd-units > ul li.systemd-unit:first-child[data-state=failed]", text: /en échec\s+fail2ban/
      assert_select ".systemd-units > ul li.systemd-unit", 5
      assert_select ".systemd-units details li.systemd-unit", 2
      assert_select "li.systemd-unit", text: /ssh\s+au démarrage/
      assert_select ".compose-project", 2
      assert_select ".compose-project", text: /ops-tools/ do
        assert_select "p", text: "ops-tools"
        assert_select ".compose-files", "/opt/ops-tools/compose.yml, /opt/ops-tools/compose.prod.yml"
        assert_select "li.docker-container[data-state=running]", 2
      end
      assert_select ".compose-project:last-child p", text: "Sans projet Compose"
      assert_select "li.docker-container[data-state=exited]", text: /arrêté\s+backup-once/
    end
  end

  test "explains unreadable containers" do
    collect(parsed.merge("docker" => "unreadable", "containers" => []), status: "partial", message: "Conteneurs Docker illisibles : permission denied")
    sign_in users(:viewer)

    get server_path(servers(:web))

    assert_select "#server-services .docker-unreadable", text: /permission denied.*groupe docker/
  end

  test "before any inventory" do
    sign_in users(:viewer)
    get server_path(servers(:web))
    assert_select "#server-services .services-empty", "Pas encore d'inventaire des services."
  end
end
