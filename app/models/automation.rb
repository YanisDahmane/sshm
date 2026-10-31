# A recurring task configured from the settings (one row per kind, created on
# first access). RunDueAutomationsJob runs every minute (config/recurring.yml)
# and starts the enabled automations whose interval has elapsed. Each one runs
# on the whole fleet or on some server groups (server_group_ids).
class Automation < ApplicationRecord
  # `categories`: inventory categories collected (Inventory::Collection) by the
  # inventory kinds. `default_enabled`: state of a new installation. `quiet`:
  # frequent tasks whose runs are not logged (what they find still is).
  Definition = Data.define(:key, :label, :description, :default_interval, :categories, :default_enabled, :quiet) do
    def initialize(key:, label:, description:, default_interval:, categories: nil, default_enabled: false, quiet: false) = super
    def inventory? = categories.present?
  end

  KINDS = [
    Definition.new(key: :health_check, label: "Suivi de la santé", default_interval: 15, categories: %w[health], default_enabled: true, quiet: true,
                   description: "Relève la charge, la mémoire, les disques, les mises à jour en attente et les services en échec ; garde 30 jours d'historique."),
    Definition.new(key: :servers_ping, label: "Vérification des serveurs", default_interval: 15, quiet: true,
                   description: "Vérifie que chaque serveur répond sur son port SSH et signale ceux qui ne répondent plus."),
    Definition.new(key: :inventory_os, label: "Inventaire du système", default_interval: 1440, categories: %w[os],
                   description: "Relit la distribution, le noyau et la machine ; signale les mises à niveau et les redémarrages."),
    Definition.new(key: :inventory_packages, label: "Inventaire des paquets", default_interval: 360, categories: %w[packages],
                   description: "Relit les paquets installés et les mises à jour disponibles ; signale les nouvelles mises à jour de sécurité."),
    Definition.new(key: :inventory_services, label: "Inventaire des services", default_interval: 60, categories: %w[services],
                   description: "Relit les services systemd et les conteneurs Docker ; signale ceux qui tombent."),
    Definition.new(key: :inventory_ports, label: "Inventaire des ports", default_interval: 60, categories: %w[ports],
                   description: "Relit les ports en écoute et le firewall ; signale les ports publics qui s'ouvrent."),
    Definition.new(key: :keys_scan, label: "Scan des clés", default_interval: 360,
                   description: "Lit les clés de tous les serveurs et signale les clés inconnues ou disparues.")
  ].index_by(&:key).freeze

  INTERVALS = { 5 => "Toutes les 5 minutes", 15 => "Toutes les 15 minutes", 60 => "Toutes les heures", 360 => "Toutes les 6 heures",
                1440 => "Tous les jours" }.freeze

  normalizes :server_group_ids, with: ->(ids) { Array(ids).compact_blank.map(&:to_i).uniq.sort }

  validates :kind, inclusion: { in: KINDS.keys.map(&:to_s) }, uniqueness: true
  validates :interval_minutes, inclusion: { in: INTERVALS.keys }

  # Every automation, in KINDS order, created with its default interval and state.
  def self.all_kinds
    KINDS.values.map do |definition|
      find_or_create_by!(kind: definition.key.to_s) do |automation|
        automation.interval_minutes = definition.default_interval
        automation.enabled = definition.default_enabled
      end
    end
  end

  def definition = KINDS.fetch(kind.to_sym)

  delegate :label, :description, :inventory?, to: :definition

  def server_groups = ServerGroup.where(id: server_group_ids).order(:name)

  # Servers the automation runs on: its groups, or the whole fleet.
  def servers
    scope = server_group_ids.any? ? Server.where(id: ServerGroupMembership.where(server_group_id: server_group_ids).select(:server_id)) : Server.all
    scope.order(:name)
  end

  def scope_label = server_group_ids.any? ? server_groups.map(&:name).join(", ") : "Tout le parc"

  def interval = interval_minutes.minutes

  def next_run_at = enabled? ? (last_run_at ? last_run_at + interval : Time.current) : nil

  def due?(now = Time.current) = enabled? && (last_run_at.nil? || last_run_at + interval <= now)

  # Runs the task now, remembers its result and logs an automation_run
  # activity (except for the quiet ones).
  # Enqueues a run, followed on the "Tâches" page except for the quiet
  # automations started on schedule. Returns the task (or nil).
  def enqueue!(user: nil, tracked: !definition.quiet)
    task = BackgroundTask.enqueue!(kind: "automation", label: label, servers: [], user: user, automation: self) if tracked
    RunAutomationJob.perform_later(self, task)
    task
  end

  # With a BackgroundTask (see RunAutomationJob), one item per server is followed.
  def run!(task: nil)
    @task = task
    result = inventory? ? run_inventory : send("run_#{kind}")
    update!(last_run_at: Time.current, last_result: result)
    Activity.record!(:automation_run, user: nil, automation: kind, automation_label: label, result: result) unless definition.quiet
    result
  end

  private

  # Collects the automation's categories on its servers, a few at a time.
  def run_inventory
    servers = self.servers.to_a
    collected = each_tracked(servers) do |server, item|
      outcomes = Inventory::Collection.call(server, categories: definition.categories)
      item&.finish_inventory!(outcomes)
      outcomes.values.none? { |outcome| outcome.status == "error" }
    end
    "#{collected.count(true)}/#{servers.size} serveur(s) inventorié(s)"
  end

  def run_keys_scan
    servers = self.servers.to_a
    detected_before = Activity.of_kind(:unknown_key_detected).count
    scanned = each_tracked(servers) do |server, item|
      scan = ServerScan.call(server)
      item&.finish!(scan.success? ? :succeeded : :failed, scan.error_title)
      scan.success?
    end.count(true)
    detected = Activity.of_kind(:unknown_key_detected).count - detected_before

    "#{scanned}/#{servers.size} serveur(s) scanné(s), #{detected} nouvelle(s) clé(s) inconnue(s)"
  end

  # Runs the block on each server, a few at a time, with its task item (if any).
  def each_tracked(servers)
    @task&.add_items!(servers)
    items = @task ? @task.items.index_by(&:server_id) : {}
    BoundedParallel.map(servers) do |server|
      item = items[server.id]
      item&.update!(status: "running", started_at: Time.current)
      yield server, item
    end
  end

  def run_servers_ping
    results = ServerPing.check_all!(servers)
    "#{results.values.count(true)}/#{results.size} serveur(s) joignable(s)"
  end
end
