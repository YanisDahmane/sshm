# Base class of the inventory collectors. A collector gathers one category
# (os, health, packages…) through an open SshConnection, with read-only
# commands, and turns their output into plain data (pure parsing, testable on
# recorded outputs):
#
#   class Inventory::Collectors::Os < Inventory::Collector
#     def collect = ok(self.class.parse(run("cat /etc/os-release").stdout))
#     def self.parse(output) = …
#   end
#
# Subclasses may also define `self.changes(previous_data, data)`, returning
# the activities to log when the data changed between two collections
# (`[{ kind: :os_upgraded, data: { … } }]`).
class Inventory::Collector
  Outcome = Data.define(:status, :data, :message)

  # Raised by a collector that cannot do its job; its message is shown in the UI.
  class Error < StandardError; end

  # Categories in collection order, with their collector class name.
  CATEGORIES = { "os" => "Inventory::Collectors::Os", "health" => "Inventory::Collectors::Health",
                 "packages" => "Inventory::Collectors::Packages", "services" => "Inventory::Collectors::Services" }.freeze

  MAX_OUTPUT = 8.megabytes

  class << self
    attr_writer :registry

    # category => collector class name, overridable in tests.
    def registry = @registry ||= CATEGORIES.dup

    def categories = registry.keys

    def for(category) = registry.fetch(category.to_s).to_s.constantize

    def changes(_previous_data, _data) = []

    # Summary columns of the server to update from the collected data.
    def server_attributes(_data) = {}

    # Extra records to keep for each successful collection (e.g. history).
    def record(_server, _data, _at) = nil

    # Part of the data kept in the snapshot (big lists can go elsewhere).
    def snapshot_data(data) = data
  end

  attr_reader :ssh

  def initialize(ssh)
    @ssh = ssh
  end

  def collect
    raise NotImplementedError
  end

  private

  # Runs a read-only command, through `sudo -n` when `privileged` and root is
  # available. Raises Error when the output is unreasonably large.
  def run(command, privileged: false, timeout: SshConnection::DEFAULT_COMMAND_TIMEOUT)
    command = ssh.privileged(command) if privileged
    ssh.exec(command, timeout: timeout).tap do |result|
      raise Error, "Sortie trop volumineuse pour « #{command.truncate(60)} »" if result.stdout.bytesize > MAX_OUTPUT
    end
  end

  def privileged? = ssh.privileged?

  def ok(data, message: nil) = Outcome.new(status: "ok", data: data, message: message)

  # Collected, but some details need root access that Elio does not have.
  def partial(data, message) = Outcome.new(status: "partial", data: data, message: message)

  def unsupported(message) = Outcome.new(status: "unsupported", data: {}, message: message)
end
