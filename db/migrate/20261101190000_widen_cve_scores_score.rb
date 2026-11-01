class WidenCveScoresScore < ActiveRecord::Migration[8.1]
  # A CVSS score of 10.0 did not fit precision 6 / scale 5 (max 9.99999); EPSS keeps its 5 decimals.
  def change
    change_column :cve_scores, :score, :decimal, precision: 7, scale: 5
  end
end
