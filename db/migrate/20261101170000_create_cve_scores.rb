class CreateCveScores < ActiveRecord::Migration[8.1]
  def change
    # Where the scores come from (built-in feeds and APIs, or custom ones), in priority order.
    create_table :score_providers do |t|
      t.string :key, null: false, index: { unique: true }
      t.string :name, null: false
      t.string :kind, null: false # nvd, redhat, cveorg, epss, kev, custom
      t.boolean :enabled, null: false, default: true
      t.integer :position, null: false, default: 0
      t.jsonb :settings, null: false, default: {}
      t.jsonb :state, null: false, default: {}
      t.datetime :last_run_at
      t.string :last_error
      t.timestamps
    end

    # What a provider says of a CVE (score nil: it has none, asked again later).
    create_table :cve_scores do |t|
      t.string :cve, null: false
      t.string :provider_key, null: false
      t.decimal :score, precision: 6, scale: 5
      t.string :version
      t.string :vector
      t.string :severity
      t.jsonb :data, null: false, default: {}
      t.datetime :fetched_at, null: false
      t.index %i[cve provider_key], unique: true
      t.index :provider_key
    end

    # One line per CVE of the fleet: the average CVSS of the enabled providers, EPSS, KEV.
    create_table :cve_ratings do |t|
      t.string :cve, null: false, index: { unique: true }
      t.decimal :score, precision: 3, scale: 1
      t.integer :scores_count, null: false, default: 0
      t.decimal :epss, precision: 6, scale: 5
      t.decimal :epss_percentile, precision: 6, scale: 5
      t.boolean :exploited, null: false, default: false
      t.date :exploited_since
      t.datetime :updated_at, null: false
    end

    # Severity of the distribution feed, kept apart: `severity` is the one in use
    # (the distribution's, else derived from the score).
    add_column :server_vulnerabilities, :distro_severity, :string
    reversible { |dir| dir.up { execute "UPDATE server_vulnerabilities SET distro_severity = severity" } }
  end
end
