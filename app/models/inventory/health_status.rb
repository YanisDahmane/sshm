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
    reasons = [ *access_reasons, *disk_reasons, *memory_reasons, *load_reasons, *system_reasons, *scheduled_task_reasons, *vulnerability_reasons, *docker_reasons, *port_reasons, *Integration.health_reasons(@server) ]
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

  def scheduled_task_reasons
    tasks = @server.inventory("scheduled_tasks")
    timers = tasks&.collected? ? Array(tasks.data["timers"]) : []
    [ [ timers.select { |timer| timer["failed"] }, "en échec" ], [ timers.select { |timer| timer["late"] && !timer["failed"] }, "en retard" ] ].filter_map do |list, state|
      next if list.empty?

      Reason.new("warn", list.one? ? "Tâche planifiée #{list.first["name"].delete_suffix(".timer")} #{state}" : "#{list.size} tâches planifiées #{state}")
    end
  end

  # Docker alerts chosen in the settings: unhealthy and looping containers, images to update.
  def docker_reasons
    docker = @server.inventory("docker")
    return [] unless docker&.collected? && docker.data["docker"] == "ok"

    containers = Array(docker.data["containers"])
    reasons = []
    reasons << grouped_reason(containers.select { |container| container["health"] == "unhealthy" }, "en mauvaise santé") if @settings.docker_alert_unhealthy
    reasons << grouped_reason(containers.select { |container| container["looping"] }, "redémarre en boucle", "redémarrent en boucle") if @settings.docker_alert_restarts
    if @settings.docker_alert_updates
      images = Array(docker.data["images"]).select { |image| image["used"] }
      updates = ImageUpdate.for_images(images)
      count = images.count { |image| ImageUpdate.state_for(image, updates) == :available }
      reasons << Reason.new("warn", count == 1 ? "1 image Docker à mettre à jour" : "#{count} images Docker à mettre à jour") if count.positive?
    end
    reasons.compact
  end

  def grouped_reason(containers, one, many = one)
    return if containers.empty?

    Reason.new("warn", containers.one? ? "Conteneur #{containers.first["name"]} #{one}" : "#{containers.size} conteneurs #{many}")
  end

  # Fixable CVEs from the alert severity of the settings: critical.
  def vulnerability_reasons
    minimum = @settings.vulnerability_alert_severity
    return [] if minimum == "none"

    cves = @server.server_vulnerabilities.fixable.at_least(minimum).distinct.pluck(:cve)
    return [] if cves.empty?

    [ Reason.new("crit", cves.one? ? "Vulnérabilité #{cves.first} corrigeable" : "#{cves.size} vulnérabilités graves corrigeables") ]
  end

  def port_reasons
    unexpected = Inventory::PortAnalysis.new(@server).unexpected_ports
    return [] if unexpected.empty?

    [ Reason.new("warn", unexpected.one? ? "Port #{unexpected.first.key} inattendu" : "#{unexpected.size} ports inattendus (#{unexpected.map(&:key).first(3).join(", ")})") ]
  end

  def threshold_reason(label, value, warn, crit)
    return unless value
    return Reason.new("crit", "#{label} à #{value.round} %") if value >= crit

    Reason.new("warn", "#{label} à #{value.round} %") if value >= warn
  end

  def format_number(value) = value.round(1).to_s.sub(".", ",").delete_suffix(",0")
end
