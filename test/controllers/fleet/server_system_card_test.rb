require "test_helper"

class ServerSystemCardTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def collect_os(server, status: "ok", collected: true, data: nil)
    data ||= Inventory::Collectors::Os.parse(file_fixture("inventory/os/debian12.txt").read)
    server.inventory_snapshots.create!(category: "os", status: status, data: collected ? data : {}, message: (status == "error" ? "Connexion impossible — timeout" : nil),
                                       collected_at: (1.hour.ago if collected), checked_at: Time.current)
  end

  test "shows the system from the last inventory" do
    servers(:web).update_columns(privilege: "sudo")
    collect_os(servers(:web))
    sign_in users(:viewer)

    get server_path(servers(:web))

    assert_select "#server-system" do
      assert_select ".os-name", "Debian GNU/Linux 12 (bookworm)"
      assert_select ".end-of-life", text: /support jusqu'au 30 juin 2028/
      assert_select "dd", text: /6\.1\.0-25-amd64\s+x86_64/
      assert_select ".machine", text: /KVM · 8 processeurs · 31,3 Go de mémoire/
      assert_select ".privilege", "sudo sans mot de passe"
      assert_select "time"
      assert_select ".inventory-status", 0
      assert_select ".system-empty", 0
    end
  end

  test "keeps the last data and shows the failure of the last try" do
    collect_os(servers(:web), status: "error")
    sign_in users(:viewer)

    get server_path(servers(:web))

    assert_select "#server-system .inventory-status", text: "Échec de l'inventaire"
    assert_select "#server-system .os-name", "Debian GNU/Linux 12 (bookworm)"
    assert_select "#server-system .inventory-error", text: /Connexion impossible — timeout/
  end

  test "a failure without any previous inventory shows the error alone" do
    collect_os(servers(:web), status: "error", collected: false)
    sign_in users(:viewer)

    get server_path(servers(:web))

    assert_select "#server-system .os-name", 0
    assert_select "#server-system .inventory-error", "Connexion impossible — timeout"
  end

  test "invites operators to run a first inventory" do
    sign_in users(:operator)
    get server_path(servers(:web))
    assert_select "#server-system .system-empty form[action=?] button", server_inventory_path(servers(:web)), text: /Lancer l'inventaire/

    sign_in users(:viewer)
    get server_path(servers(:web))
    assert_select "#server-system .system-empty"
    assert_select "#server-system .system-empty form", 0
  end
end
