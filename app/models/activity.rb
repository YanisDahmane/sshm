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
    Kind.new(:automation_run, "Automatisation exécutée", :configuration, :info, "Une automatisation s'est exécutée.")
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

  # One-line French description of what happened.
  def summary
    case kind.to_sym
    when :key_added
      duration = data["duration_label"] ? " pendant #{data["duration_label"]}" : ""
      "« #{public_key_name} » ajoutée sur #{target}#{duration}"
    when :key_removed then "Clé « #{key_name} » supprimée de #{target}"
    when :key_expired then "Accès temporaire de « #{public_key_name || key_name} » retiré de #{target}"
    when :unknown_key_detected then "Clé inconnue « #{key_name} » trouvée sur #{target}"
    when :key_disappeared then "Clé « #{key_name} » disparue de #{target}"
    when :ssh_access_lost then "« #{server_name} » refuse la clé d'Elio"
    when :host_key_changed then "Nouvelle empreinte acceptée pour « #{server_name} » : #{data["new_fingerprint"]}"
    when :server_unreachable then "« #{server_name} » ne répond plus"
    when :server_back_online then "« #{server_name} » répond à nouveau"
    when :server_created then "Serveur « #{server_name} » ajouté"
    when :server_updated then "Serveur « #{server_name} » modifié"
    when :servers_imported
      names = data["names"].to_a
      more = data["count"].to_i > names.size ? "…" : ""
      "#{data["count"]} serveur(s) importé(s) (#{data["format"]}) : #{names.join(", ")}#{more}"
    when :server_deleted then "Serveur « #{server_name} » supprimé d'Elio"
    when :server_group_created then "Groupe « #{data["group_name"]} » créé (#{data["servers"]} serveur(s))"
    when :server_group_deleted then "Groupe « #{data["group_name"]} » supprimé"
    when :user_invited then "#{data["email"]} invité (#{data["role_label"]})"
    when :invitation_accepted then "#{data["email"]} a rejoint Elio (#{data["role_label"]})"
    when :invitation_revoked then "Invitation de #{data["email"]} révoquée"
    when :user_role_changed then "Rôle de #{data["email"]} : #{data["from"]} → #{data["to"]}"
    when :user_deactivated then "#{data["email"]} désactivé"
    when :user_reactivated then "#{data["email"]} réactivé"
    when :user_locked then "#{data["email"]} verrouillé après #{data["attempts"]} essais ratés"
    when :two_factor_enabled then "2FA activée pour #{data["email"]}"
    when :two_factor_disabled then data["reset_by"] ? "2FA de #{data["email"]} réinitialisée par #{data["reset_by"]}" : "2FA désactivée pour #{data["email"]}"
    when :two_factor_backup_code_used then "#{data["email"]} s'est connecté avec un code de secours (#{data["left"]} restant(s))"
    when :public_key_created then "Clé « #{public_key_name} » ajoutée au trousseau"
    when :public_key_deleted then "Clé « #{public_key_name} » retirée du trousseau"
    when :ssh_key_generated then data["regenerated"] ? "Clé Elio régénérée" : "Clé Elio générée"
    when :ssh_key_rotation_started then "Rotation de la clé Elio lancée sur #{data["servers"]} serveur(s)"
    when :ssh_key_rotated
      forced = data["forced"] ? " (finalisée malgré #{data["failed"]} échec(s))" : ""
      "Clé Elio remplacée sur #{data["servers"]} serveur(s)#{forced}"
    when :automation_run then "#{data["automation_label"]} : #{data["result"]}"
    end
  end
end
