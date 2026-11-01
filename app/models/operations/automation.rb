# A recurring task configured from the settings (one row per kind, created on
# first access). RunDueAutomationsJob runs every minute (config/recurring.yml)
# and starts the enabled automations whose interval has elapsed. Each one runs
# on the whole fleet or on some server groups (server_group_ids).
class Automation < ApplicationRecord
  # `categories`: inventory categories collected (Inventory::Collection) by the
  # inventory kinds. `default_enabled`: state of a new installation. `quiet`:
  # frequent tasks whose runs are not logged (what they find still is).
  # `integration`: synchronization of an extension (Integration), only
  # available while the extension is enabled.
  Definition = Data.define(:key, :label, :description, :default_interval, :categories, :default_enabled, :quiet, :integration) do
    def initialize(key:, label:, description:, default_interval:, categories: nil, default_enabled: false, quiet: false, integration: nil) = super
    def inventory? = categories.present?
    def available? = integration.nil? || Integration.enabled?(integration)
  end

  KINDS = [
    Definition.new(key: :health_check, label: "Suivi de la santé", default_interval: 15, categories: %w[health], default_enabled: true, quiet: true,
                   description: "Relève la charge, la mémoire, les disques, les mises à jour en attente et les services en échec ; garde 30 jours d'historique."),
    Definition.new(key: :servers_ping, label: "Vérification des serveurs", default_interval: 15, quiet: true,
                   description: "Vérifie que chaque serveur répond sur son port SSH et signale ceux qui ne répondent plus."),
    Definition.new(key: :inventory_os, label: "Inventaire du système", default_interval: 1440, categories: %w[os network],
                   description: "Relit la distribution, le noyau, la machine et ses adresses IP ; signale les mises à niveau, les redémarrages et les adresses publiques qui changent."),
    Definition.new(key: :inventory_packages, label: "Inventaire des paquets", default_interval: 360, categories: %w[packages],
                   description: "Relit les paquets installés et les mises à jour disponibles ; signale les nouvelles mises à jour de sécurité."),
    Definition.new(key: :inventory_services, label: "Inventaire des services", default_interval: 60, categories: %w[services scheduled_tasks docker],
                   description: "Relit les services systemd, Docker (conteneurs, images et leurs vulnérabilités) et les tâches planifiées (cron, timers) ; signale ceux qui tombent ou échouent."),
    Definition.new(key: :inventory_ports, label: "Inventaire des ports", default_interval: 60, categories: %w[ports],
                   description: "Relit les ports en écoute et le firewall ; signale les ports publics qui s'ouvrent."),
    Definition.new(key: :vulnerabilities_update, label: "Mise à jour des vulnérabilités", default_interval: 1440, default_enabled: true,
                   description: "Télécharge les bases de vulnérabilités (Debian Security Tracker, Ubuntu) pour les versions du parc et les rapproche des paquets installés."),
    Definition.new(key: :cve_scores_update, label: "Notes de gravité des CVE", default_interval: 360, default_enabled: true,
                   description: "Demande aux fournisseurs de notes (NVD, Red Hat, CVE.org, EPSS, CISA KEV…) la note des CVE du parc pas encore notées, et en déduit la gravité de celles que la distribution n'évalue pas."),
    Definition.new(key: :docker_image_updates, label: "Mises à jour des images Docker", default_interval: 360, default_enabled: true,
                   description: "Demande aux registres (Docker Hub, GHCR…) la dernière version de chaque image utilisée sur le parc, en lecture seule."),
    Definition.new(key: :keys_scan, label: "Scan des clés", default_interval: 360,
                   description: "Lit les clés de tous les serveurs et signale les clés inconnues ou disparues."),
    Definition.new(key: :uptime_kuma_sync, label: "Synchronisation Uptime Kuma", default_interval: 15, default_enabled: true, quiet: true, integration: "uptime_kuma",
                   description: "Relit les sondes d'Uptime Kuma, les rattache aux serveurs et lève les alertes choisies dans l'extension."),
    Definition.new(key: :ovh_sync, label: "Synchronisation OVHcloud", default_interval: 360, default_enabled: true, integration: "ovh",
                   description: "Relit les ressources OVHcloud (IP, firewall, DNS, services), les rattache aux serveurs et lève les alertes choisies.")
  ].index_by(&:key).freeze

  INTERVALS = { 5 => "Toutes les 5 minutes", 15 => "Toutes les 15 minutes", 60 => "Toutes les heures", 360 => "Toutes les 6 heures",
                1440 => "Tous les jours" }.freeze

  normalizes :server_group_ids, with: ->(ids) { Array(ids).compact_blank.map(&:to_i).uniq.sort }

  validates :kind, inclusion: { in: KINDS.keys.map(&:to_s) }, uniqueness: true
  validates :interval_minutes, inclusion: { in: INTERVALS.keys }

  # Every automation, in KINDS order, created with its default interval and state.
  # Automations offered in the interface (those of a disabled extension aside).
  def self.available = all_kinds.select(&:available?)

  def self.all_kinds
    KINDS.values.map do |definition|
      find_or_create_by!(kind: definition.key.to_s) do |automation|
        automation.interval_minutes = definition.default_interval
        automation.enabled = definition.default_enabled
      end
    end
  end

  ALREADY_RUNNING = "Déjà en cours : ce passage est ignoré."

  def definition = KINDS.fetch(kind.to_sym)

  # Runs an automation now because something needs it (a release new to the
  # fleet needs the vulnerability feeds, new CVEs need their scores), unless
  # it is disabled — a closed network turns it off — or already waiting or
  # running. Returns the task, or nil.
  def self.trigger(kind)
    automation = all_kinds.find { |candidate| candidate.kind == kind.to_s }
    start = automation.with_lock do
      automation.enabled? && automation.available? && !BackgroundTask.unfinished.exists?(automation: automation)
    end
    automation.enqueue!(tracked: true) if start
  end

  delegate :label, :description, :inventory?, :available?, to: :definition

  def server_groups = ServerGroup.where(id: server_group_ids).order(:name)

  # Servers the automation runs on: its groups, or the whole fleet.
  def servers
    scope = server_group_ids.any? ? Server.where(id: ServerGroupMembership.where(server_group_id: server_group_ids).select(:server_id)) : Server.all
    scope.order(:name)
  end

  def scope_label = server_group_ids.any? ? server_groups.map(&:name).join(", ") : "Tout le parc"

  def interval = interval_minutes.minutes

  def next_run_at = enabled? ? (last_run_at ? last_run_at + interval : Time.current) : nil

  def due?(now = Time.current) = enabled? && available? && (last_run_at.nil? || last_run_at + interval <= now)

  # Runs the task now, remembers its result and logs an automation_run
  # activity (except for the quiet ones).
  # Enqueues a run, followed on the "Tâches" page except for the quiet
  # automations started on schedule. Returns the task (or nil).
  def enqueue!(user: nil, tracked: !definition.quiet)
    task = BackgroundTask.enqueue!(kind: "automation", label: label, servers: [], user: user, automation: self) if tracked
    RunAutomationJob.perform_later(self, task)
    task
  end

  # "Lancer maintenant": the task already waiting or running if there is one
  # (a second run would only wait for the first), else a new one.
  # Returns [task, started].
  def start_now!(user:)
    running = BackgroundTask.unfinished.where(automation: self).order(:id).last
    running ? [ running, false ] : [ enqueue!(user: user, tracked: true), true ]
  end

  # With a BackgroundTask (see RunAutomationJob), one item per server is followed.
  # Never twice at the same time (two workers, a run started by hand while the
  # scheduled one runs): the second run is skipped and says so.
  def run!(task: nil)
    @task = task
    result = AdvisoryLock.try("automation:#{kind}") do
      if inventory? then run_inventory
      elsif definition.integration then run_integration_sync
      else send("run_#{kind}")
      end
    end
    return ALREADY_RUNNING if result.equal?(AdvisoryLock::HELD)

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
      scan = Keys::ServerScan.call(server)
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

  # Synchronization of an extension (does nothing once it is disabled).
  def run_integration_sync
    integration = Integration.find_enabled(definition.integration)
    return "Extension désactivée : rien à faire" unless integration

    integration.sync!
  rescue Integrations::Error => e
    "Échec : #{e.message}"
  end

  # Downloads the feeds of the releases used on the fleet. A failure is
  # logged once (vulnerability_feed_failed), until a download works again.
  def run_vulnerabilities_update
    Vulnerability::SOURCES.keys.map do |source|
      feed = VulnerabilityFeed.for(source)
      failing = feed.failed?
      Vulnerabilities::Update.call(source)
    rescue Vulnerabilities::Error => e
      Activity.record!(:vulnerability_feed_failed, user: nil, feed: feed.label, error: e.message) unless failing
      "#{feed.label} : échec (#{e.message})"
    end.join(" · ").tap do
      # CVEs never asked to the score providers (the first download, a new
      # release): their scores now, not at the next run in a few hours.
      Automation.trigger(:cve_scores_update) if ServerVulnerability.where.not(cve: CveScore.select(:cve)).exists?
    end
  end

  def run_docker_image_updates = ImageRegistry::UpdateCheck.call

  def run_cve_scores_update = Vulnerabilities::Scores.update_all

  def run_servers_ping
    results = Servers::Ping.check_all!(servers)
    "#{results.values.count(true)}/#{results.size} serveur(s) joignable(s)"
  end
end
