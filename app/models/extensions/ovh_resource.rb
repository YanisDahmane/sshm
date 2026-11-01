# A resource read from OVHcloud (see Integrations::Ovh), attached to the
# server it belongs to when one matches.
class OvhResource < ApplicationRecord
  KINDS = { "ip" => "Adresse IP", "dns_record" => "Enregistrement DNS", "dedicated" => "Serveur dédié", "vps" => "VPS", "instance" => "Instance Public Cloud" }.freeze
  SERVICE_KINDS = %w[dedicated vps instance].freeze
  MATCHES = { "address" => "par son adresse IP", "service" => "par le service OVH de l'IP", "name" => "par son nom", "cname" => "par l'enregistrement visé",
              "manual" => "à la main" }.freeze

  belongs_to :server, optional: true

  scope :of_kind, ->(kind) { where(kind: kind) }
  scope :services, -> { where(kind: SERVICE_KINDS) }
  scope :attached, -> { where.not(server_id: nil) }
  scope :unattached, -> { where(server_id: nil) }

  def kind_label = KINDS.fetch(kind, kind)
  def service? = SERVICE_KINDS.include?(kind)
  def link_key = "#{kind}:#{external_id}"

  def days_left = expires_at && (expires_at - Date.current).to_i
end
