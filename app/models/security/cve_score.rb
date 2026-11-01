# What one provider says of a CVE: a CVSS score (0-10) with its version and
# vector, or for EPSS a probability (0-1), for KEV the date it was added.
# A nil score is remembered too (the provider has none), asked again later.
class CveScore < ApplicationRecord
  # Asked again after (a found score rarely changes; a missing one may appear).
  REFRESH = 30.days
  REFRESH_MISSING = 7.days

  belongs_to :provider, class_name: "ScoreProvider", primary_key: :key, foreign_key: :provider_key, optional: true

  scope :scored, -> { where.not(score: nil) }

  # Upserts a batch of { cve:, score:, version:, vector:, severity:, data: } for a provider.
  def self.store(provider_key, rows)
    now = Time.current
    rows = rows.map { |row| { cve: row[:cve], provider_key: provider_key, score: row[:score], version: row[:version], vector: row[:vector],
                              severity: row[:severity], data: row[:data] || {}, fetched_at: now } }
    upsert_all(rows, unique_by: %i[cve provider_key]) if rows.any?
  end

  # CVEs of `cves` to ask a provider for: never asked or asked too long ago.
  def self.due(provider_key, cves)
    known = where(provider_key: provider_key, cve: cves).pluck(:cve, :score, :fetched_at).to_h { |cve, score, at| [ cve, [ score, at ] ] }
    cves.select do |cve|
      score, at = known[cve]
      at.nil? || at < (score ? REFRESH : REFRESH_MISSING).ago
    end.sort_by { |cve| known.key?(cve) ? 1 : 0 }
  end
end
