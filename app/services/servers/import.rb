require "csv"

# Parses servers to import from a CSV file (name, host, port, user, groups)
# or from an OpenSSH client config (~/.ssh/config: Host / HostName / Port /
# User), checks each row with the Server validations and flags duplicates,
# so the page can show a preview before anything is created.
class Servers::Import
  class Error < StandardError; end

  FORMATS = { "csv" => "CSV", "ssh_config" => "~/.ssh/config" }.freeze
  MAX_ROWS = 500
  MAX_SIZE = 200.kilobytes

  # CSV header names (normalized: lowercase, without accents) → attribute.
  CSV_HEADERS = {
    "name" => :name, "nom" => :name, "host" => :host, "hote" => :host, "hostname" => :host, "adresse" => :host, "ip" => :host,
    "port" => :port, "user" => :username, "username" => :username, "utilisateur" => :username, "groups" => :groups, "groupes" => :groups,
    "group" => :groups, "groupe" => :groups
  }.freeze
  CSV_COLUMNS = %i[name host port username groups].freeze

  Row = Data.define(:line, :name, :host, :port, :username, :group_names, :errors, :duplicate_of) do
    def status = errors.any? ? :invalid : (duplicate_of ? :duplicate : :valid)
    def valid? = status == :valid
  end

  def self.parse(text, format:, default_username: "root")
    raise Error, "Collez ou choisissez un fichier." if text.blank?
    raise Error, "Le fichier est trop gros (#{MAX_SIZE / 1.kilobyte} Ko maximum)." if text.bytesize > MAX_SIZE

    text = text.dup.force_encoding(Encoding::UTF_8).delete_prefix("﻿")
    raise Error, "Le fichier n'est pas en UTF-8." unless text.valid_encoding?

    entries = case format.to_s
    when "csv" then csv_entries(text)
    when "ssh_config" then ssh_config_entries(text)
    else raise Error, "Format inconnu."
    end
    raise Error, "Aucun serveur trouvé dans le fichier." if entries.empty?
    raise Error, "Trop de lignes (#{MAX_ROWS} serveurs maximum par import)." if entries.size > MAX_ROWS

    check(entries, default_username.to_s.strip.presence || "root")
  end

  # Creates the valid rows (and the groups they name) in one transaction.
  def self.import!(rows)
    groups = {}
    ApplicationRecord.transaction do
      rows.select(&:valid?).map do |row|
        server_groups = row.group_names.map do |name|
          groups[name.downcase] ||= ServerGroup.where("lower(name) = ?", name.downcase).first || ServerGroup.create!(name: name)
        end
        Server.create!(name: row.name, host: row.host, port: row.port, username: row.username, server_groups: server_groups)
      end
    end
  end

  # [{ line:, name:, host:, port:, username:, groups: }] from CSV, with or
  # without a header row; ";" separated files (spreadsheets in French) work too.
  def self.csv_entries(text)
    first_line = text.lines.first.to_s
    separator = first_line.count(";") > first_line.count(",") ? ";" : ","
    rows = CSV.parse(text, col_sep: separator)

    header = rows.first.map { |cell| CSV_HEADERS[I18n.transliterate(cell.to_s.strip.downcase)] }
    has_header = header.include?(:host)
    columns = has_header ? header : CSV_COLUMNS
    offset = has_header ? 2 : 1

    rows.drop(has_header ? 1 : 0).each_with_index.filter_map do |cells, index|
      next if cells.all?(&:blank?)

      values = columns.zip(cells).select(&:first).to_h { |column, value| [ column, value.to_s.strip ] }
      { line: index + offset, name: values[:name], host: values[:host], port: values[:port], username: values[:username],
        groups: values[:groups].to_s.split(/[;|,]/).map(&:squish).reject(&:blank?).uniq(&:downcase) }
    end
  rescue CSV::MalformedCSVError => e
    raise Error, "CSV invalide : #{e.message}"
  end

  # One entry per concrete `Host` block (patterns with * ? ! and `Match`
  # blocks are skipped); the first alias is the name, HostName defaults to it.
  def self.ssh_config_entries(text)
    entries = []
    current = nil
    text.each_line.with_index(1) do |raw, number|
      line = raw.sub(/#.*/, "").strip
      next if line.empty?

      key, value = line.split(/\s*=\s*|\s+/, 2)
      case key.downcase
      when "host"
        alias_name = value.to_s.split.first.to_s
        current = alias_name.match?(/[*?!]/) ? nil : { line: number, name: alias_name, host: nil, port: nil, username: nil, groups: [] }
        entries << current if current
      when "match" then current = nil
      when "hostname" then current[:host] = value if current
      when "port" then current[:port] = value if current
      when "user" then current[:username] = value if current
      end
    end
    entries.each { |entry| entry[:host] ||= entry[:name] }
  end

  def self.check(entries, default_username)
    existing_names = Server.pluck(:name).index_by(&:downcase)
    existing_addresses = Server.pluck(:host, :port, :name).to_h { |host, port, name| [ [ host.downcase, port ], name ] }
    seen = {}

    entries.map do |entry|
      port = entry[:port].presence || 22
      server = Server.new(name: entry[:name].to_s, host: entry[:host].to_s, port: port, username: entry[:username].presence || default_username)
      server.validate
      errors = server.errors.reject { |error| error.type == :taken }.map(&:full_message)
      errors += entry[:groups].select { |name| name.length > 50 }.map { |name| "Groupe « #{name.first(20)}… » trop long" }

      key = server.name.downcase
      duplicate = existing_names[key] || seen[key] || existing_addresses[[ server.host.downcase, server.port ]]
      seen[key] ||= server.name if server.name.present?

      Row.new(entry[:line], server.name, server.host, server.port, server.username, entry[:groups], errors, duplicate)
    end
  end

  private_class_method :csv_entries, :ssh_config_entries, :check
end
