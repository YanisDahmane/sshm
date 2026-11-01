# A manual matching of an external resource (a probe, an IP…) with a server,
# kept across synchronizations. server nil = "attached to no server" (an
# automatic match refused by hand).
class IntegrationLink < ApplicationRecord
  belongs_to :integration
  belongs_to :server, optional: true
  belongs_to :user, optional: true

  validates :external_id, presence: true, uniqueness: { scope: :integration_id }
end
