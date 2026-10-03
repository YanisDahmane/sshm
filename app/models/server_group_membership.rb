class ServerGroupMembership < ApplicationRecord
  belongs_to :server
  belongs_to :server_group

  validates :server_id, uniqueness: { scope: :server_group_id }
end
