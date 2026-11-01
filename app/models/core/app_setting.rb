# Application-wide settings (a single row).
class AppSetting < ApplicationRecord
  validates :health_disk_warn, :health_disk_crit, :health_memory_warn, :health_memory_crit,
            numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 100 }
  validates :health_load_warn, numericality: { greater_than: 0, less_than_or_equal_to: 50 }
  validate :warning_thresholds_below_critical
  # From which severity a fixable CVE is a critical health reason and an activity ("none": never).
  # Debian rates few issues (most are "not yet assigned"): "any" alerts on every fixable one.
  VULNERABILITY_ALERTS = { "critical" => "Critique", "high" => "Haute ou critique", "medium" => "Moyenne ou plus",
                           "any" => "Toutes les corrigeables", "none" => "Jamais" }.freeze
  validates :vulnerability_alert_severity, inclusion: { in: VULNERABILITY_ALERTS.keys }
  # Colours of the CVSS scores: three bands, each from a score (0 to 10, increasing).
  SCORE_COLORS = { "green" => "Vert", "orange" => "Orange", "red" => "Rouge", "violet" => "Violet", "blue" => "Bleu", "gray" => "Gris" }.freeze
  validate :score_bands_valid

  # Colour of a score ("green"…), nil without a score.
  def score_color(score)
    return if score.nil?

    score_bands.sort_by { |band| band["from"].to_f }.reverse.find { |band| score.to_f >= band["from"].to_f }&.dig("color") || score_bands.first["color"]
  end

  # From the settings form: { "0" => { "from" => "0", "color" => "green" }, … }.
  def score_bands_form=(values)
    self.score_bands = values.to_h.values.map { |band| { "from" => band["from"].to_s.tr(",", ".").to_f, "color" => band["color"].to_s } }
  end

  # "registry user token" lines (ImageRegistry::UpdateCheck.credentials).
  encrypts :docker_registry_credentials

  def self.current = first || create!

  private

  def score_bands_valid
    froms = score_bands.map { |band| band["from"].to_f }
    errors.add(:score_bands, "doivent être trois paliers") unless score_bands.size == 3
    errors.add(:score_bands, "commencent à 0 et montent jusqu'à 10 au plus") unless froms.first&.zero? && froms == froms.sort && froms.uniq.size == froms.size && froms.all? { |from| from.between?(0, 10) }
    errors.add(:score_bands, "ont une couleur inconnue") unless score_bands.all? { |band| SCORE_COLORS.key?(band["color"]) }
  end

  def warning_thresholds_below_critical
    errors.add(:health_disk_warn, :less_than, count: health_disk_crit) if health_disk_warn.to_i >= health_disk_crit.to_i
    errors.add(:health_memory_warn, :less_than, count: health_memory_crit) if health_memory_warn.to_i >= health_memory_crit.to_i
  end
end
