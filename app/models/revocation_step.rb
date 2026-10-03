# Result of a Revocation on one account of a server, or on a whole server when
# its accounts could not be listed (unix_user nil).
class RevocationStep < ApplicationRecord
  belongs_to :revocation
  belongs_to :server, optional: true

  enum :status, { removed: "removed", absent: "absent", failed: "failed" }, validate: true

  validates :server_name, presence: true

  def server_level? = unix_user.nil?
end
