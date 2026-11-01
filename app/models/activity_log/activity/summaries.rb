# One-line French description of each kind of activity, run in the
# context of the Activity (data, server_name, target, key_name…). Every
# kind of Activity::KINDS has one (see activity_test.rb).
module Activity::Summaries
  BY_KIND = {
    key_added: proc do
      duration = data["duration_label"] ? " pendant #{data["duration_label"]}" : ""
      "« #{public_key_name} » ajoutée sur #{target}#{duration}"
    end,
    key_removed: proc { "Clé « #{key_name} » supprimée de #{target}" },
    key_expired: proc { "Accès temporaire de « #{public_key_name || key_name} » retiré de #{target}" },
    unknown_key_detected: proc { "Clé inconnue « #{key_name} » trouvée sur #{target}" },
    key_disappeared: proc { "Clé « #{key_name} » disparue de #{target}" },
    ssh_access_lost: proc { "« #{server_name} » refuse la clé d'Elio" },
    host_key_changed: proc { "Nouvelle empreinte acceptée pour « #{server_name} » : #{data["new_fingerprint"]}" },
    server_unreachable: proc { "« #{server_name} » ne répond plus" },
    server_back_online: proc { "« #{server_name} » répond à nouveau" },
    os_upgraded: proc { "« #{server_name} » est passé de #{data["from"]} à #{data["to"]}" },
    server_rebooted: proc { "« #{server_name} » a redémarré" },
    health_warning: proc { "« #{server_name} » est à surveiller : #{Array(data["reasons"]).map { |reason| Inventory::HealthStatus.text(reason) }.join(", ")}" },
    health_critical: proc { "« #{server_name} » est en état critique : #{Array(data["reasons"]).map { |reason| Inventory::HealthStatus.text(reason) }.join(", ")}" },
    health_recovered: proc { "« #{server_name} » est de nouveau sain" },
    packages_changed: proc do
      counts = { "installed" => "installé", "upgraded" => "mis à jour", "removed" => "supprimé" }
                 .filter_map { |key, label| "#{data[key]} #{label}#{"s" if data[key].to_i > 1}" if data[key].to_i.positive? }
      "Paquets de « #{server_name} » : #{counts.join(", ")}#{" (#{Array(data["examples"]).join(", ")})" if Array(data["examples"]).any?}"
    end,
    service_failed: proc { "#{data["service"]} est en échec sur « #{server_name} »" },
    service_recovered: proc { "#{data["service"]} fonctionne à nouveau sur « #{server_name} »" },
    container_stopped: proc { "Le conteneur #{data["container"]} s'est arrêté sur « #{server_name} »" },
    container_started: proc { "Le conteneur #{data["container"]} tourne à nouveau sur « #{server_name} »" },
    scheduled_task_failed: proc { "La tâche planifiée #{data["task"]} a échoué sur « #{server_name} »" },
    scheduled_task_late: proc { "La tâche planifiée #{data["task"]} n'a pas tourné à temps sur « #{server_name} »" },
    vulnerability_found: proc do
      where = data["image"] ? "l'image #{data["image"]} de « #{server_name} »" : "« #{server_name} »"
      "#{data["count"]} vulnérabilité(s) corrigeable(s) sur #{where} : #{Array(data["cves"]).join(", ")}#{" (#{Array(data["packages"]).join(", ")})" if Array(data["packages"]).any?}"
    end,
    vulnerability_feed_failed: proc { "Base de vulnérabilités #{data["feed"]} non mise à jour : #{data["error"]}" },
    container_unhealthy: proc { "Le conteneur #{data["container"]} est en mauvaise santé sur « #{server_name} »" },
    container_restarting: proc { "Le conteneur #{data["container"]} redémarre en boucle sur « #{server_name} »" },
    image_update_available: proc { "Nouvelle version de l'image #{data["image"]} pour « #{server_name} »" },
    port_opened: proc { "Port #{data["port"]} ouvert publiquement sur « #{server_name} »#{" (#{data["process"]})" if data["process"]}" },
    port_closed: proc { "Port #{data["port"]} fermé sur « #{server_name} »" },
    ip_address_added: proc { "Nouvelle adresse publique #{data["address"]} sur « #{server_name} »" },
    ip_address_removed: proc { "Adresse publique #{data["address"]} retirée de « #{server_name} »" },
    security_updates_available: proc { "#{data["count"]} mise(s) à jour de sécurité disponible(s) sur « #{server_name} »" },
    server_created: proc { "Serveur « #{server_name} » ajouté" },
    server_updated: proc { "Serveur « #{server_name} » modifié" },
    servers_imported: proc do
      names = data["names"].to_a
      more = data["count"].to_i > names.size ? "…" : ""
      "#{data["count"]} serveur(s) importé(s) (#{data["format"]}) : #{names.join(", ")}#{more}"
    end,
    server_deleted: proc { "Serveur « #{server_name} » supprimé d'Elio" },
    server_group_created: proc { "Groupe « #{data["group_name"]} » créé (#{data["servers"]} serveur(s))" },
    server_group_deleted: proc { "Groupe « #{data["group_name"]} » supprimé" },
    user_invited: proc { "#{data["email"]} invité (#{data["role_label"]})" },
    invitation_accepted: proc { "#{data["email"]} a rejoint Elio (#{data["role_label"]})" },
    invitation_revoked: proc { "Invitation de #{data["email"]} révoquée" },
    user_role_changed: proc { "Rôle de #{data["email"]} : #{data["from"]} → #{data["to"]}" },
    user_deactivated: proc { "#{data["email"]} désactivé" },
    user_reactivated: proc { "#{data["email"]} réactivé" },
    user_locked: proc { "#{data["email"]} verrouillé après #{data["attempts"]} essais ratés" },
    two_factor_enabled: proc { "2FA activée pour #{data["email"]}" },
    two_factor_disabled: proc { data["reset_by"] ? "2FA de #{data["email"]} réinitialisée par #{data["reset_by"]}" : "2FA désactivée pour #{data["email"]}" },
    two_factor_backup_code_used: proc { "#{data["email"]} s'est connecté avec un code de secours (#{data["left"]} restant(s))" },
    public_key_created: proc { "Clé « #{public_key_name} » ajoutée au trousseau" },
    public_key_deleted: proc { "Clé « #{public_key_name} » retirée du trousseau" },
    ssh_key_generated: proc { data["regenerated"] ? "Clé Elio régénérée" : "Clé Elio générée" },
    ssh_key_rotation_started: proc { "Rotation de la clé Elio lancée sur #{data["servers"]} serveur(s)" },
    ssh_key_rotated: proc do
      forced = data["forced"] ? " (finalisée malgré #{data["failed"]} échec(s))" : ""
      "Clé Elio remplacée sur #{data["servers"]} serveur(s)#{forced}"
    end,
    automation_run: proc { "#{data["automation_label"]} : #{data["result"]}" },
    monitor_down: proc { "Sonde « #{data["monitor"]} » hors ligne#{" (#{server_name})" if server_name}" },
    monitor_up: proc { "Sonde « #{data["monitor"]} » de retour#{" (#{server_name})" if server_name}" },
    monitor_cert_expiring: proc { "Certificat de « #{data["monitor"]} » : expire dans #{data["days"]} jour(s)" },
    server_without_monitor: proc { "« #{server_name} » n'est surveillé par aucune sonde Uptime Kuma" },
    ovh_service_expiring: proc { "Service OVH « #{data["service"]} » : expire dans #{data["days"]} jour(s)" },
    dns_record_outside_fleet: proc { "#{data["record"]} pointe vers #{data["target"]}, hors du parc" },
    ovh_service_unmanaged: proc { "#{data["kind_label"]} OVH « #{data["service"]} » rattaché à aucun serveur" },
    integration_enabled: proc { "Extension #{data["integration_label"]} activée" },
    integration_disabled: proc { "Extension #{data["integration_label"]} désactivée" },
    integration_sync_failed: proc { "Synchronisation #{data["integration_label"]} impossible : #{data["error"]}" }
  }.freeze
end
