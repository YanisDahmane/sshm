require "test_helper"

class ServerHealthTest < ActiveSupport::TestCase
  setup do
    @server = servers(:web)
    @server.update_columns(ssh_ok: true, reachable: true)
  end

  def collect_health(**data)
    snapshot = @server.inventory_snapshots.find_or_initialize_by(category: "health")
    snapshot.update!(status: "ok", data: { "load" => [ 0.1 ], "cpus" => 2, "disks" => [] }.merge(data.stringify_keys),
                     collected_at: Time.current, checked_at: Time.current)
    @server.refresh_health!
  end

  test "stores the state and its reasons, without activity the first time" do
    assert_no_difference("Activity.count") { collect_health(reboot_required: true) }

    assert_equal "warn", @server.health_status
    assert_equal [ "Redémarrage requis" ], @server.health_reason_texts
    assert_equal "warn", @server.health_state
  end

  test "logs when the state gets worse, becomes critical or recovers, not when it stays the same" do
    collect_health

    assert_difference("Activity.of_kind(:health_warning).count") { collect_health(reboot_required: true) }
    assert_no_difference("Activity.count") { collect_health(reboot_required: true) }
    assert_difference("Activity.of_kind(:health_critical).count") do
      collect_health(disks: [ { "mount" => "/", "used_percent" => 97 } ])
    end
    assert_equal "« Web » est en état critique : Disque / à 97 %", Activity.of_kind(:health_critical).sole.summary
    assert_difference("Activity.of_kind(:health_recovered).count") { collect_health }
    assert_equal "critical", Activity::KINDS.fetch(:health_critical).severity.to_s
  end

  test "an unreachable server is shown off, whatever its inventory" do
    collect_health
    @server.update_columns(reachable: false)

    assert_equal [ "ok", "off" ], [ @server.health_status, @server.health_state ]
    assert_equal "unknown", Server.new.health_state
  end

  test "a refused key recomputes the health of an inventoried server" do
    collect_health

    @server.record_ssh_status!(false)

    assert_equal [ "crit", [ "Clé Elio refusée : inventaire impossible" ] ], [ @server.health_status, @server.health_reason_texts ]
    assert Activity.of_kind(:health_critical).exists?
  end
end
