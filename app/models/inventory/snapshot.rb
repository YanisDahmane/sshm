# Last known result of one inventory category on a server. `data` keeps the
# last successful collection; a later failure only updates `status`,
# `message` and `checked_at`, so the previous data stays visible.
#
# Statuses: ok, partial (collected without root, some details missing),
# error (could not collect), unsupported (not available on this system).
class Inventory::Snapshot < ApplicationRecord
  STATUSES = %w[ok partial error unsupported].freeze

  belongs_to :server

  validates :category, presence: true, uniqueness: { scope: :server_id }
  validates :status, inclusion: { in: STATUSES }
  validates :checked_at, presence: true

  scope :of_category, ->(category) { where(category: category.to_s) }

  def collected? = collected_at.present?

  def failed? = status == "error"
end
