# Application-wide settings (a single row).
class AppSetting < ApplicationRecord
  validates :health_disk_warn, :health_disk_crit, :health_memory_warn, :health_memory_crit,
            numericality: { only_integer: true, greater_than: 0, less_than_or_equal_to: 100 }
  validates :health_load_warn, numericality: { greater_than: 0, less_than_or_equal_to: 50 }
  validate :warning_thresholds_below_critical

  def self.current = first || create!

  private

  def warning_thresholds_below_critical
    errors.add(:health_disk_warn, :less_than, count: health_disk_crit) if health_disk_warn.to_i >= health_disk_crit.to_i
    errors.add(:health_memory_warn, :less_than, count: health_memory_crit) if health_memory_warn.to_i >= health_memory_crit.to_i
  end
end
