# Collects inventory categories of a server in a single SSH session and
# records them (Inventory::Snapshot), along with the server's root access and
# SSH status. Each category is isolated: a failing collector, a timeout or a
# parsing bug only marks its own category as failed. Activities for what
# changed are logged from the second collection on (never on the first one).
#
# Never raises; returns { category => Inventory::Collector::Outcome }.
class Inventory::Collection
  def self.call(server, categories: Inventory::Collector.categories, **connection_options)
    new(server, categories.map(&:to_s), connection_options).call
  end

  def initialize(server, categories, connection_options)
    @server = server
    @categories = categories
    @connection_options = connection_options
  end

  def call
    outcomes = {}
    privilege = nil

    SshConnection.open(@server, **@connection_options) do |ssh|
      privilege = ssh.privilege
      @categories.each { |category| outcomes[category] = collect(category, ssh) }
    end

    record(outcomes, privilege)
    @server.refresh_health!
    outcomes
  rescue SshConnection::Error => e
    @server.record_ssh_status!(false) if e.reason == :key_refused
    failed = @categories.index_with { error_outcome("#{e.title} — #{e.message}") }
    failed.each { |category, outcome| save_snapshot(category, outcome, privileged: false) }
    @server.refresh_health!
    failed
  end

  private

  def collect(category, ssh)
    Inventory::Collector.for(category).new(ssh).collect
  rescue SshConnection::CommandTimeoutError, Inventory::Collector::Error => e
    error_outcome(e.message)
  rescue SshConnection::Error => e
    error_outcome("#{e.title} — #{e.message}")
  rescue StandardError => e
    Rails.error.report(e, context: { server_id: @server.id, category: category })
    error_outcome("Erreur interne pendant la collecte (#{e.class})")
  end

  def record(outcomes, privilege)
    now = Time.current
    @server.update_columns(privilege: privilege.to_s, inventoried_at: now)
    @server.record_ssh_status!(true)
    outcomes.each { |category, outcome| save_snapshot(category, outcome, privileged: privilege != :none, now: now) }
  end

  def save_snapshot(category, outcome, privileged:, now: Time.current)
    snapshot = @server.inventory_snapshots.find_or_initialize_by(category: category)
    previous = snapshot.collected? ? snapshot.data : nil

    if outcome.status == "error"
      snapshot.update!(status: "error", message: outcome.message, checked_at: now)
    else
      snapshot.update!(status: outcome.status, message: outcome.message, data: outcome.data, privileged: privileged,
                       collected_at: now, checked_at: now)
      log_changes(category, previous, outcome.data) if previous
      collector = Inventory::Collector.for(category)
      attributes = collector.server_attributes(outcome.data.as_json)
      @server.update_columns(attributes) if attributes.any?
      collector.record(@server, outcome.data.as_json, now)
    end
  end

  def log_changes(category, previous, data)
    Inventory::Collector.for(category).changes(previous, data.as_json).each do |change|
      Activity.record!(change.fetch(:kind), server: @server, user: nil, **change.fetch(:data, {}))
    end
  end

  def error_outcome(message) = Inventory::Collector::Outcome.new(status: "error", data: {}, message: message)
end
