# Fixes drift reported by DriftDetector. Adding the missing keys is safe
# (and is what the automatic correction does); removing extra keys is only
# done one key at a time, by a person, from the drift page.
module DriftCorrection
  # Grants the missing profiles of each scanned entry; returns BulkAccess results.
  def self.add_missing(entries)
    entries.select { |entry| entry.scanned? && entry.missing.any? }.flat_map do |entry|
      BulkAccess.grant(entry.missing, [ entry.server ], account: entry.unix_user)
    end
  end
end
