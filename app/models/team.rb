# A set of profiles (e.g. "Développeurs", "Astreinte") that can be granted or
# revoked on servers in one go (see BulkAccess). Membership lives in Elio
# only: the servers still get one authorized_keys line per profile.
class Team < ApplicationRecord
  has_many :memberships, class_name: "TeamMembership", dependent: :delete_all
  has_many :access_rules, dependent: :delete_all
  has_many :profiles, -> { order(:name) }, through: :memberships

  normalizes :name, with: ->(value) { value.squish }
  normalizes :description, with: ->(value) { value.strip.presence }

  validates :name, presence: true, uniqueness: { case_sensitive: false }, length: { maximum: 50 }
  validates :description, length: { maximum: 500 }
end
