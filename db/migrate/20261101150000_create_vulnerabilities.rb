class CreateVulnerabilities < ActiveRecord::Migration[8.1]
  def change
    # Source package of each dpkg package (the vulnerability feeds are by source package and version).
    add_column :inventory_packages, :source_name, :string
    add_column :inventory_packages, :source_version, :string

    # Vulnerability feeds (Debian Security Tracker, Ubuntu OSV), one row per CVE, source package and release.
    create_table :vulnerabilities do |t|
      t.string :source, null: false
      t.string :release, null: false
      t.string :package, null: false
      t.string :cve, null: false
      t.string :fixed_version
      t.string :severity, null: false, default: "unknown"
      t.string :description
      t.index %i[source release package cve], unique: true, name: "index_vulnerabilities_uniqueness"
      t.index :cve
    end

    create_table :vulnerability_feeds do |t|
      t.string :source, null: false, index: { unique: true }
      t.datetime :refreshed_at
      t.string :origin
      t.integer :entries_count, null: false, default: 0
      t.jsonb :releases, null: false, default: []
      t.datetime :failed_at
      t.string :last_error
    end

    # CVEs affecting a server: its packages (origin host) or a Docker image (origin image, lot 8.2).
    create_table :server_vulnerabilities do |t|
      t.references :server, null: false, foreign_key: { on_delete: :cascade }
      t.string :origin, null: false, default: "host"
      t.string :source, null: false
      t.string :image
      t.string :cve, null: false
      t.string :source_package, null: false
      t.string :packages, array: true, null: false, default: []
      t.string :installed_version
      t.string :fixed_version
      t.string :severity, null: false
      t.string :description
      t.index :cve
      t.index %i[server_id origin]
    end

    add_column :servers, :vulnerabilities_checked_at, :datetime
    add_column :app_settings, :vulnerability_alert_severity, :string, null: false, default: "high"
  end
end
