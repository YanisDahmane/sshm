# Log of what happened (keys added / removed / detected, servers, settings…).
# Each kind is declared in KINDS with a label, a category and a severity, so a
# future notification system can let users pick which kinds notify them.
# Names are copied into `data` so entries stay readable after a deletion.
class Activity < ApplicationRecord
  Kind = Data.define(:key, :label, :category, :severity, :description)

  CATEGORIES = { keys: "Clés SSH", servers: "Serveurs", security: "Sécurité", configuration: "Configuration" }.freeze
  SEVERITIES = %i[info warning critical].freeze

  KINDS = [
    Kind.new(:key_added, "Clé ajoutée", :keys, :info, "Un profil a été autorisé sur un compte d'un serveur."),
    Kind.new(:key_removed, "Clé supprimée", :keys, :info, "Une clé a été supprimée d'un compte depuis SSHM."),
    Kind.new(:key_expired, "Accès temporaire expiré", :keys, :info, "Un accès temporaire a expiré et sa clé a été retirée."),
    Kind.new(:unknown_key_detected, "Clé sans profil détectée", :security, :warning, "Une clé qui ne correspond à aucun profil a été trouvée sur un serveur."),
    Kind.new(:key_disappeared, "Clé retirée hors de SSHM", :security, :warning, "Une clé a disparu d'un serveur sans passer par SSHM."),
    Kind.new(:ssh_access_lost, "Accès SSH perdu", :security, :critical, "Le serveur refuse désormais la clé de SSHM."),
    Kind.new(:server_unreachable, "Serveur injoignable", :servers, :warning, "Un serveur ne répond plus sur son port SSH."),
    Kind.new(:server_back_online, "Serveur de nouveau joignable", :servers, :info, "Un serveur injoignable répond à nouveau."),
    Kind.new(:server_created, "Serveur ajouté", :servers, :info, "Un serveur a été ajouté à SSHM."),
    Kind.new(:server_updated, "Serveur modifié", :servers, :info, "Les informations de connexion d'un serveur ont changé."),
    Kind.new(:profile_created, "Profil créé", :configuration, :info, "Un profil a été créé."),
    Kind.new(:profile_deleted, "Profil supprimé", :configuration, :info, "Un profil a été supprimé."),
    Kind.new(:ssh_key_generated, "Clé SSHM générée", :security, :critical, "La clé SSH de SSHM a été générée ou régénérée."),
    Kind.new(:automation_run, "Automatisation exécutée", :configuration, :info, "Une automatisation s'est exécutée.")
  ].index_by(&:key).freeze

  belongs_to :user, optional: true
  belongs_to :server, optional: true
  belongs_to :profile, optional: true

  validates :kind, inclusion: { in: KINDS.keys.map(&:to_s) }

  after_create_commit -> { NotifyActivityJob.perform_later(self) }

  scope :recent, -> { order(created_at: :desc, id: :desc) }
  scope :of_kind, ->(kind) { where(kind: kind.to_s) }
  scope :in_category, ->(category) { where(kind: KINDS.values.select { |kind| kind.category == category.to_sym }.map { |kind| kind.key.to_s }) }

  # Records an activity; the author defaults to the signed-in user (Current.user).
  def self.record!(kind, server: nil, profile: nil, unix_user: nil, user: Current.user, **data)
    data[:server_name] ||= server&.name
    data[:profile_name] ||= profile&.name
    create!(kind: kind.to_s, server: server, profile: profile, unix_user: unix_user, user: user, data: data.compact)
  end

  def definition = KINDS.fetch(kind.to_sym)

  delegate :label, :category, :severity, to: :definition

  def author_name = user&.email || "Système"

  def server_name = server&.name || data["server_name"]

  def profile_name = profile&.name || data["profile_name"]

  def key_name = data["key_name"] || "sans nom"

  def target = [ server_name && "« #{server_name} »", unix_user && "pour #{unix_user}" ].compact.join(" ")

  # One-line French description of what happened.
  def summary
    case kind.to_sym
    when :key_added
      duration = data["duration_label"] ? " pendant #{data["duration_label"]}" : ""
      "« #{profile_name} » autorisé sur #{target}#{duration}"
    when :key_removed then "Clé « #{key_name} » supprimée de #{target}"
    when :key_expired then "Accès temporaire de « #{profile_name || key_name} » retiré de #{target}"
    when :unknown_key_detected then "Clé « #{key_name} » sans profil trouvée sur #{target}"
    when :key_disappeared then "Clé « #{key_name} » disparue de #{target}"
    when :ssh_access_lost then "« #{server_name} » refuse la clé de SSHM"
    when :server_unreachable then "« #{server_name} » ne répond plus"
    when :server_back_online then "« #{server_name} » répond à nouveau"
    when :server_created then "Serveur « #{server_name} » ajouté"
    when :server_updated then "Serveur « #{server_name} » modifié"
    when :profile_created then "Profil « #{profile_name} » créé"
    when :profile_deleted then "Profil « #{profile_name} » supprimé"
    when :ssh_key_generated then data["regenerated"] ? "Clé SSHM régénérée" : "Clé SSHM générée"
    when :automation_run then "#{data["automation_label"]} : #{data["result"]}"
    end
  end
end
