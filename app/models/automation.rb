# A recurring task configured from the settings (one row per kind, created on
# first access). RunDueAutomationsJob runs every minute (config/recurring.yml)
# and starts the enabled automations whose interval has elapsed.
class Automation < ApplicationRecord
  Definition = Data.define(:key, :label, :description, :default_interval)

  KINDS = [
    Definition.new(:keys_scan, "Scan des clés",
                   "Lit les clés de tous les comptes de tous les serveurs et signale les clés sans profil ou disparues.", 360),
    Definition.new(:servers_ping, "Vérification des serveurs",
                   "Vérifie que chaque serveur répond sur son port SSH et signale ceux qui ne répondent plus.", 15)
  ].index_by(&:key).freeze

  INTERVALS = { 15 => "Toutes les 15 minutes", 60 => "Toutes les heures", 360 => "Toutes les 6 heures", 1440 => "Tous les jours" }.freeze

  validates :kind, inclusion: { in: KINDS.keys.map(&:to_s) }, uniqueness: true
  validates :interval_minutes, inclusion: { in: INTERVALS.keys }

  # Every automation, in KINDS order, created disabled with its default interval.
  def self.all_kinds
    KINDS.values.map { |definition| find_or_create_by!(kind: definition.key.to_s) { |automation| automation.interval_minutes = definition.default_interval } }
  end

  def definition = KINDS.fetch(kind.to_sym)

  delegate :label, :description, to: :definition

  def interval = interval_minutes.minutes

  def next_run_at = enabled? ? (last_run_at ? last_run_at + interval : Time.current) : nil

  def due?(now = Time.current) = enabled? && (last_run_at.nil? || last_run_at + interval <= now)

  # Runs the task now, remembers its result and logs an automation_run activity.
  def run!
    result = send("run_#{kind}")
    update!(last_run_at: Time.current, last_result: result)
    Activity.record!(:automation_run, user: nil, automation: kind, automation_label: label, result: result)
    result
  end

  private

  def run_keys_scan
    servers = Server.order(:name).to_a
    detected_before = Activity.of_kind(:unknown_key_detected).count
    scanned = servers.count { |server| ServerScan.call(server).success? }
    detected = Activity.of_kind(:unknown_key_detected).count - detected_before

    "#{scanned}/#{servers.size} serveur(s) scanné(s), #{detected} nouvelle(s) clé(s) sans profil"
  end

  def run_servers_ping
    results = ServerPing.check_all!(Server.all)
    "#{results.values.count(true)}/#{results.size} serveur(s) joignable(s)"
  end
end
