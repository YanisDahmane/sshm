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

  # Badge of an inventory snapshot that is not plainly ok.
  def inventory_status_badge(snapshot)
    case snapshot&.status
    when "error" then status_badge(:crit, "Échec de l'inventaire", title: snapshot.message, class: "inventory-status")
    when "partial" then status_badge(:warn, "Partiel", title: snapshot.message, class: "inventory-status")
    when "unsupported" then status_badge(:neutral, "Non disponible", title: snapshot.message, class: "inventory-status")
    end
  end

  # "Debian GNU/Linux 12 (bookworm)" → "Debian 12", for dense lists (full name in a title).
  def short_os_name(name) = name.to_s.sub("GNU/Linux ", "").sub(/\s*\([^)]*\)\z/, "").squish
end
