# A package installed on a server (see Inventory::Collectors::Packages):
# dpkg package, snap or Docker image, with the update available if any.
class Inventory::Package < ApplicationRecord
  MANAGERS = { "dpkg" => "Debian (dpkg)", "snap" => "Snap", "docker" => "Image Docker" }.freeze

  belongs_to :server

  scope :upgradable, -> { where.not(available_version: nil) }
  scope :security, -> { where(security: true) }
  scope :search, ->(query) { where("inventory_packages.name ILIKE ?", "%#{sanitize_sql_like(query.to_s.strip)}%") }

  def manager_label = MANAGERS.fetch(manager, manager)

  def upgradable? = available_version.present?
end
