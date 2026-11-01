# Log of what happened (keys added / removed / detected, servers, settings…).
# Each kind is declared in KINDS with a label, a category and a severity, so a
# future notification system can let users pick which kinds notify them.
# Names are copied into `data` so entries stay readable after a deletion.
class Activity < ApplicationRecord
  Kind = Data.define(:key, :label, :category, :severity, :description)

  CATEGORIES = { keys: "Clés SSH", servers: "Serveurs", security: "Sécurité", configuration: "Configuration" }.freeze
  SEVERITIES = %i[info warning critical].freeze

  KINDS = [
    Kind.new(:key_added, "Clé ajoutée", :keys, :info, "Une clé du trousseau a été ajoutée sur un serveur."),
    Kind.new(:key_removed, "Clé supprimée", :keys, :info, "Une clé a été supprimée d'un compte depuis Elio."),
    Kind.new(:key_expired, "Accès temporaire expiré", :keys, :info, "Un accès temporaire a expiré et sa clé a été retirée."),
    Kind.new(:unknown_key_detected, "Clé inconnue détectée", :security, :warning, "Une clé absente du trousseau a été trouvée sur un serveur."),
    Kind.new(:key_disappeared, "Clé retirée hors d'Elio", :security, :warning, "Une clé a disparu d'un serveur sans passer par Elio."),
    Kind.new(:ssh_access_lost, "Accès SSH perdu", :security, :critical, "Le serveur refuse désormais la clé d'Elio."),
    Kind.new(:host_key_changed, "Empreinte serveur remplacée", :security, :critical, "Un administrateur a accepté la nouvelle empreinte d'un serveur (réinstallation…)."),
    Kind.new(:server_unreachable, "Serveur injoignable", :servers, :warning, "Un serveur ne répond plus sur son port SSH."),
    Kind.new(:server_back_online, "Serveur de nouveau joignable", :servers, :info, "Un serveur injoignable répond à nouveau."),
    Kind.new(:os_upgraded, "Système mis à niveau", :servers, :info, "La version du système d'un serveur a changé (inventaire)."),
    Kind.new(:server_rebooted, "Serveur redémarré", :servers, :info, "Un serveur a redémarré depuis le dernier inventaire."),
    Kind.new(:health_warning, "Serveur à surveiller", :servers, :warning, "La santé d'un serveur se dégrade (disque, mémoire, charge, redémarrage requis…)."),
    Kind.new(:health_critical, "Serveur en état critique", :servers, :critical, "Un seuil critique est dépassé sur un serveur (disque ou mémoire presque pleins…)."),
    Kind.new(:health_recovered, "Serveur de nouveau sain", :servers, :info, "Un serveur à surveiller ou critique est revenu à la normale."),
    Kind.new(:packages_changed, "Paquets modifiés", :servers, :info, "Des paquets ont été installés, mis à jour ou supprimés sur un serveur (inventaire)."),
    Kind.new(:service_failed, "Service en échec", :servers, :warning, "Un service systemd est passé en échec (inventaire)."),
    Kind.new(:service_recovered, "Service rétabli", :servers, :info, "Un service systemd en échec fonctionne à nouveau."),
    Kind.new(:container_stopped, "Conteneur arrêté", :servers, :warning, "Un conteneur Docker qui tournait s'est arrêté."),
    Kind.new(:container_started, "Conteneur redémarré", :servers, :info, "Un conteneur Docker arrêté tourne à nouveau."),
    Kind.new(:scheduled_task_failed, "Tâche planifiée en échec", :servers, :warning, "Le dernier passage d'un timer systemd a échoué (inventaire)."),
    Kind.new(:scheduled_task_late, "Tâche planifiée en retard", :servers, :warning, "Un timer systemd n'a pas tourné depuis plus de deux fois sa période."),
    Kind.new(:vulnerability_found, "Vulnérabilité corrigeable", :security, :warning, "Une vulnérabilité (CVE) grave et corrigeable touche un serveur ou une de ses images Docker (gravité choisie dans les paramètres)."),
    Kind.new(:vulnerability_feed_failed, "Base de vulnérabilités non mise à jour", :configuration, :warning, "Le téléchargement ou l'import d'une base de vulnérabilités a échoué (signalé une fois, jusqu'au retour à la normale)."),
    Kind.new(:container_unhealthy, "Conteneur en mauvaise santé", :servers, :warning, "Le healthcheck d'un conteneur Docker échoue (alerte au choix dans Paramètres → Docker)."),
    Kind.new(:container_restarting, "Conteneur qui redémarre en boucle", :servers, :warning, "Un conteneur Docker redémarre sans cesse (alerte au choix dans Paramètres → Docker)."),
    Kind.new(:image_update_available, "Nouvelle version d'image", :servers, :info, "Le registre publie une nouvelle version d'une image Docker utilisée (alerte au choix dans Paramètres → Docker)."),
    Kind.new(:port_opened, "Port public ouvert", :security, :warning, "Un nouveau port écoute sur une adresse publique d'un serveur."),
    Kind.new(:port_closed, "Port public fermé", :security, :info, "Un port public n'écoute plus sur un serveur."),
    Kind.new(:ip_address_added, "Nouvelle adresse IP publique", :servers, :info, "Une adresse IP publique apparaît sur une interface d'un serveur."),
    Kind.new(:ip_address_removed, "Adresse IP publique retirée", :servers, :info, "Une adresse IP publique n'est plus configurée sur un serveur."),
    Kind.new(:security_updates_available, "Mises à jour de sécurité", :security, :warning, "Des mises à jour de sécurité sont disponibles sur un serveur qui n'en avait pas."),
    Kind.new(:server_created, "Serveur ajouté", :servers, :info, "Un serveur a été ajouté à Elio."),
    Kind.new(:server_updated, "Serveur modifié", :servers, :info, "Les informations de connexion d'un serveur ont changé."),
    Kind.new(:servers_imported, "Serveurs importés", :servers, :info, "Des serveurs ont été importés depuis un fichier CSV ou un ~/.ssh/config."),
    Kind.new(:server_deleted, "Serveur supprimé", :servers, :warning, "Un serveur a été retiré d'Elio (ses clés restent installées dessus)."),
    Kind.new(:server_group_created, "Groupe de serveurs créé", :configuration, :info, "Un groupe de serveurs a été créé."),
    Kind.new(:server_group_deleted, "Groupe de serveurs supprimé", :configuration, :info, "Un groupe de serveurs a été supprimé (ses serveurs restent)."),
    Kind.new(:user_invited, "Utilisateur invité", :configuration, :info, "Une invitation à rejoindre Elio a été créée."),
    Kind.new(:invitation_accepted, "Invitation acceptée", :security, :warning, "Un nouvel utilisateur a rejoint Elio."),
    Kind.new(:invitation_revoked, "Invitation révoquée", :configuration, :info, "Une invitation en attente a été annulée."),
    Kind.new(:user_role_changed, "Rôle modifié", :security, :warning, "Le rôle d'un utilisateur a changé."),
    Kind.new(:user_deactivated, "Utilisateur désactivé", :security, :warning, "Un compte a été désactivé : il ne peut plus se connecter."),
    Kind.new(:user_reactivated, "Utilisateur réactivé", :security, :warning, "Un compte désactivé peut de nouveau se connecter."),
    Kind.new(:user_locked, "Compte verrouillé", :security, :warning, "Trop d'essais de connexion ratés : le compte est bloqué 15 minutes."),
    Kind.new(:two_factor_enabled, "2FA activée", :security, :info, "Un utilisateur a activé la double authentification."),
    Kind.new(:two_factor_disabled, "2FA désactivée", :security, :critical, "La double authentification d'un utilisateur a été désactivée ou réinitialisée."),
    Kind.new(:two_factor_backup_code_used, "Code de secours utilisé", :security, :warning, "Un utilisateur s'est connecté avec un code de secours."),
    Kind.new(:public_key_created, "Clé ajoutée au trousseau", :configuration, :info, "Une clé a été ajoutée au trousseau."),
    Kind.new(:public_key_deleted, "Clé retirée du trousseau", :configuration, :info, "Une clé a été retirée du trousseau (elle reste sur les serveurs)."),
    Kind.new(:ssh_key_generated, "Clé Elio générée", :security, :critical, "La clé SSH d'Elio a été générée ou régénérée."),
    Kind.new(:ssh_key_rotation_started, "Rotation de la clé Elio lancée", :security, :warning, "Une nouvelle clé Elio est en cours d'installation sur les serveurs."),
    Kind.new(:ssh_key_rotated, "Clé Elio remplacée", :security, :critical, "La rotation est terminée : la nouvelle clé Elio est active, l'ancienne supprimée."),
    Kind.new(:automation_run, "Automatisation exécutée", :configuration, :info, "Une automatisation s'est exécutée."),
    Kind.new(:monitor_down, "Sonde hors ligne", :servers, :critical, "Une sonde Uptime Kuma rattachée à un serveur est hors ligne (option de l'extension)."),
    Kind.new(:monitor_up, "Sonde de retour", :servers, :info, "Une sonde Uptime Kuma hors ligne répond de nouveau."),
    Kind.new(:monitor_cert_expiring, "Certificat bientôt expiré", :security, :warning, "Le certificat vérifié par une sonde Uptime Kuma expire bientôt."),
    Kind.new(:server_without_monitor, "Serveur sans sonde", :servers, :warning, "Un serveur n'est surveillé par aucune sonde Uptime Kuma."),
    Kind.new(:ovh_service_expiring, "Service OVH bientôt expiré", :servers, :warning, "Un service OVHcloud (dédié, VPS) arrive à expiration."),
    Kind.new(:dns_record_outside_fleet, "DNS vers une IP hors du parc", :security, :warning, "Un enregistrement DNS OVH pointe vers une IP qui n'est à aucun serveur du parc."),
    Kind.new(:ovh_service_unmanaged, "Service OVH non suivi", :servers, :info, "Un service OVHcloud n'est rattaché à aucun serveur du parc."),
    Kind.new(:integration_enabled, "Extension activée", :configuration, :info, "Un administrateur a activé une extension."),
    Kind.new(:integration_disabled, "Extension désactivée", :configuration, :info, "Un administrateur a désactivé une extension."),
    Kind.new(:integration_sync_failed, "Échec de synchronisation d'une extension", :configuration, :warning, "Une extension n'arrive plus à lire son service (signalé une fois, jusqu'au retour à la normale).")
  ].index_by(&:key).freeze

  belongs_to :user, optional: true
  belongs_to :server, optional: true
  belongs_to :public_key, optional: true

  validates :kind, inclusion: { in: KINDS.keys.map(&:to_s) }

  after_create_commit -> { NotifyActivityJob.perform_later(self) }

  scope :recent, -> { order(created_at: :desc, id: :desc) }
  scope :of_kind, ->(kind) { where(kind: kind.to_s) }
  scope :in_category, ->(category) { where(kind: KINDS.values.select { |kind| kind.category == category.to_sym }.map { |kind| kind.key.to_s }) }

  # Records an activity; the author defaults to the signed-in user (Current.user).
  def self.record!(kind, server: nil, public_key: nil, unix_user: nil, user: Current.user, **data)
    data[:server_name] ||= server&.name
    data[:public_key_name] ||= public_key&.name
    create!(kind: kind.to_s, server: server, public_key: public_key, unix_user: unix_user, user: user, data: data.compact)
  end

  def definition = KINDS.fetch(kind.to_sym)

  delegate :label, :category, :severity, to: :definition

  def author_name = user&.email || "Système"

  def server_name = server&.name || data["server_name"]

  def public_key_name = public_key&.name || data["public_key_name"]

  def key_name = data["key_name"] || "sans nom"

  def target = server_name && "« #{server_name} »"

  # One-line French description of what happened (Activity::Summaries).
  def summary = instance_exec(&Summaries::BY_KIND.fetch(kind.to_sym))
end
