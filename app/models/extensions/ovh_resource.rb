# A resource read from OVHcloud (see Integrations::Ovh), attached to the
# server it belongs to when one matches.
class OvhResource < ApplicationRecord
  KINDS = %w[ip dns_record dedicated vps instance].freeze
  SERVICE_KINDS = %w[dedicated vps instance].freeze
  MATCHES = %w[address service name cname manual].freeze # labels: ovh_resource.matches.*

  belongs_to :server, optional: true

  scope :of_kind, ->(kind) { where(kind: kind) }
  scope :services, -> { where(kind: SERVICE_KINDS) }
  scope :attached, -> { where.not(server_id: nil) }
  scope :unattached, -> { where(server_id: nil) }

  def kind_label = I18n.t("ovh_resource.kinds.#{kind}", default: kind.to_s)
  def service? = SERVICE_KINDS.include?(kind)
  def link_key = "#{kind}:#{external_id}"

  def days_left = expires_at && (expires_at - Date.current).to_i
end
