# Health state of a server from its last inventory and the thresholds of
# AppSetting: ok, warn or crit with the reasons, or unknown before any health
# collection. Unreachability is shown on top of it (Server#health_state).
class Inventory::HealthStatus
  Reason = Data.define(:tone, :text)
  Result = Data.define(:state, :reasons)

  def self.evaluate(server, settings: AppSetting.current) = new(server, settings).evaluate

  def initialize(server, settings)
    @server = server
    @settings = settings
    @health = server.inventory("health")
    @os = server.inventory("os")
  end

  def evaluate
    reasons = [ *access_reasons, *disk_reasons, *memory_reasons, *load_reasons, *system_reasons ]
    reasons = reasons.sort_by { |reason| reason.tone == "crit" ? 0 : 1 }
    state = if reasons.any? { |reason| reason.tone == "crit" } then "crit"
    elsif reasons.any? then "warn"
    elsif @health&.collected? then "ok"
    else "unknown"
    end
    Result.new(state: state, reasons: reasons)
  end

  private

  def data = @health&.collected? ? @health.data : {}

  def access_reasons
    @server.ssh_ok == false ? [ Reason.new("crit", "Clé Elio refusée : inventaire impossible") ] : []
  end

  def disk_reasons
    Array(data["disks"]).flat_map do |disk|
      [ threshold_reason("Disque #{disk["mount"]}", disk["used_percent"], @settings.health_disk_warn, @settings.health_disk_crit),
        threshold_reason("Inodes #{disk["mount"]}", disk["inodes_used_percent"], @settings.health_disk_warn, @settings.health_disk_crit) ].compact
    end
  end

  def memory_reasons
    [ threshold_reason("Mémoire", data.dig("memory", "used_percent"), @settings.health_memory_warn, @settings.health_memory_crit) ].compact
  end

  def load_reasons
    load, cpus = data["load"]&.first, data["cpus"]
    return [] unless load && cpus.to_i.positive? && load >= cpus * @settings.health_load_warn.to_f

    [ Reason.new("warn", "Charge #{format_number(load)} pour #{cpus} processeur#{"s" if cpus > 1}") ]
  end

  def system_reasons
    reasons = []
    reasons << Reason.new("warn", "Redémarrage requis") if data["reboot_required"]
    failed = Array(data["failed_units"])
    reasons << Reason.new("warn", failed.one? ? "#{failed.first.delete_suffix(".service")} en échec" : "#{failed.size} services en échec") if failed.any?
    reasons << Reason.new("warn", "Horloge non synchronisée") if data["ntp_synchronized"] == false
    if @os&.collected? && Inventory::EndOfLife.status(@os.data["id"], @os.data["version_id"]).ended?
      reasons << Reason.new("warn", "#{@os.data["name"]} n'est plus supporté")
    end
    reasons
  end

  def threshold_reason(label, value, warn, crit)
    return unless value
    return Reason.new("crit", "#{label} à #{value.round} %") if value >= crit

    Reason.new("warn", "#{label} à #{value.round} %") if value >= warn
  end

  def format_number(value) = value.round(1).to_s.sub(".", ",").delete_suffix(",0")
end
