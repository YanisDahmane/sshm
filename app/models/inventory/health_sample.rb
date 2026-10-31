# One point of a server's health history (load, memory and fullest disk, in
# percent), written at each health collection and kept RETENTION.
class Inventory::HealthSample < ApplicationRecord
  RETENTION = 30.days

  belongs_to :server

  scope :since, ->(time) { where(collected_at: time..).order(:collected_at) }

  def self.purge!(now: Time.current) = where(collected_at: ...(now - RETENTION)).delete_all
end
