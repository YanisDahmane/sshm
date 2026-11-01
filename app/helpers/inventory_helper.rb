# Formatting of the inventory data (see Inventory::Collectors).
module InventoryHelper
  VIRTUALIZATION_LABELS = {
    "none" => "Machine physique", "kvm" => "KVM", "qemu" => "QEMU", "vmware" => "VMware", "microsoft" => "Hyper-V",
    "oracle" => "VirtualBox", "xen" => "Xen", "amazon" => "AWS", "lxc" => "Conteneur LXC", "docker" => "Conteneur Docker",
    "podman" => "Conteneur Podman", "openvz" => "OpenVZ", "wsl" => "WSL"
  }.freeze

  PRIVILEGE_LABELS = { "root" => "connecté en root", "sudo" => "sudo sans mot de passe", "none" => "aucun (inventaire partiel)" }.freeze

  def virtualization_label(value) = VIRTUALIZATION_LABELS.fetch(value.to_s, value.to_s.capitalize.presence || "Inconnue")

  def privilege_label(value) = PRIVILEGE_LABELS.fetch(value.to_s, "inconnu")

  # 31,3 Go
  def human_bytes(bytes) = bytes ? number_to_human_size(bytes, precision: 3, significant: true) : "—"

  # End of support of the server's system: a warning when it is near or past,
  # a discreet date otherwise, nothing when the release is unknown.
  def end_of_life_badge(os_id, version_id)
    status = Inventory::EndOfLife.status(os_id, version_id)
    return unless status.known?

    date = l(status.date, format: :long)
    case status.state
    when :ended then status_badge(:crit, "Plus supporté depuis le #{date}", class: "end-of-life")
    when :soon then status_badge(:warn, "Fin de support le #{date}", class: "end-of-life")
    else tag.span("support jusqu'au #{date}", class: "end-of-life text-xs text-ink-3")
    end
  end

  PERIOD_LABELS = { "hourly" => "toutes les heures", "daily" => "tous les jours", "weekly" => "toutes les semaines", "monthly" => "tous les mois" }.freeze

  # Readable schedules of a timer ("OnCalendar=*-*-* 06:00:00" → "tous les jours à 6 h 00").
  def timer_schedule_text(timer)
    Array(timer["schedules"]).map { |schedule| Inventory::CronSchedule.timer(schedule).text }.join(" · ").presence || "—"
  end

  def cron_schedule_text(task) = Inventory::CronSchedule.cron(task["schedule"]).text

  # State of a systemd timer: failed, late, inactive or ok.
  def timer_state_badge(timer)
    if timer["failed"] then status_badge(:crit, "en échec", title: "Dernier passage : #{timer["result"]} (code #{timer["exit_status"]})", class: "timer-state")
    elsif timer["late"] then status_badge(:warn, "en retard", class: "timer-state")
    elsif timer["active"] != "active" then status_badge(:neutral, "inactif", class: "timer-state")
    else status_badge(:good, "ok", class: "timer-state")
    end
  end

  def timer_time(value) = value ? relative_time_tag(Time.zone.parse(value)) : tag.span("—", class: "text-ink-3")

  SEVERITY_TONES = { "critical" => :crit, "high" => :crit, "medium" => :warn, "low" => :neutral, "unknown" => :neutral }.freeze

  def severity_badge(severity)
    status_badge(SEVERITY_TONES.fetch(severity.to_s, :neutral), Vulnerability.severity_label(severity), class: "severity", data: { severity: severity })
  end

  # Badge of an inventory snapshot that is not plainly ok.
  def inventory_status_badge(snapshot)
    case snapshot&.status
    when "error" then status_badge(:crit, "Échec de l'inventaire", title: snapshot.message, class: "inventory-status")
    when "partial" then status_badge(:warn, "Partiel", title: snapshot.message, class: "inventory-status")
    when "unsupported" then status_badge(:neutral, "Non disponible", title: snapshot.message, class: "inventory-status")
    end
  end

  def network_kind_label(kind) = Inventory::Collectors::Network::KINDS.fetch(kind.to_s, kind.to_s.capitalize)

  # Reach of an address: public, private (LAN, VPN) or local.
  def address_scope_badge(scope)
    case scope
    when "public" then status_badge(:warn, "publique", icon: :globe, class: "address-scope")
    when "private" then status_badge(:neutral, "privée", class: "address-scope")
    else status_badge(:neutral, "locale", class: "address-scope")
    end
  end

  # "Debian GNU/Linux 12 (bookworm)" → "Debian 12", for dense lists (full name in a title).
  def short_os_name(name) = name.to_s.sub("GNU/Linux ", "").sub(/\s*\([^)]*\)\z/, "").squish
end
