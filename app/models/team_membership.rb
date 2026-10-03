class TeamMembership < ApplicationRecord
  belongs_to :team
  belongs_to :profile

  validates :profile_id, uniqueness: { scope: :team_id }
end
