require "test_helper"

class ServerPortsCardTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include PortHelpers

  test "shows the ports, their exposure and firewall state, the Docker warning and the ufw rules" do
    servers(:db).update_columns(port: 22)
    server_groups(:production).update!(expected_ports: "22, 6432")
    record_ports(servers(:db))
    record_containers(servers(:db), [ { "name" => "pgbouncer", "state" => "running", "ports" => "0.0.0.0:6432->6432/tcp" } ])
    sign_in users(:viewer)

    get server_path(servers(:db), tab: "ports")

    assert_select "#server-ports" do
      assert_select ".ports-summary", text: /3 publics sur 8 en écoute/
      assert_select ".firewall-state", text: "Firewall : ufw actif (entrant : bloqué par défaut)"
      assert_select ".ports-summary", text: /Ports attendus : 22, 6432/
      assert_select ".docker-bypass", text: /DOCKER-USER/
      assert_select "tr.port", 8
      assert_select "tr.port:first-child", text: /22\/tcp.*0\.0\.0\.0, ::.*public.*sshd.*ssh.*autorisé/m
      assert_select "tr.port", text: /6432\/tcp.*conteneur pgbouncer.*publié par Docker/m
      assert_select "tr.port", text: /9100\/tcp\s+inattendu.*bloqué/m
      assert_select "tr.port[data-scope=local]", 3
      assert_select "details.ufw-rules[data-controller=clipboard] textarea[data-clipboard-target=source]", text: /sudo ufw allow 22\/tcp comment 'ssh \(Elio\)'/
    end
  end

  test "before any inventory" do
    sign_in users(:viewer)
    get server_path(servers(:web), tab: "ports")
    assert_select "#server-ports .ports-empty", "Pas encore d'inventaire des ports."
  end
end
