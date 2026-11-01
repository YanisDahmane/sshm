# A probe of Uptime Kuma (see Integrations::UptimeKuma), attached to the
# server it watches when one matches.
class UptimeKumaMonitor < ApplicationRecord
  STATUSES = { 1 => "up", 0 => "down", 2 => "pending", 3 => "maintenance" }.freeze
  MATCHES = { "ip" => "par son adresse IP", "url" => "par l'hôte de son URL", "dns" => "par résolution DNS", "name" => "par son nom", "manual" => "à la main" }.freeze

  belongs_to :server, optional: true

  scope :attached, -> { where.not(server_id: nil) }
  scope :unattached, -> { where(server_id: nil) }
  scope :by_name, -> { order(Arel.sql("LOWER(uptime_kuma_monitors.name)")) }

  def state = STATUSES.fetch(status, "unknown")
  def down? = status == 0

  # What the probe checks: its host name / IP (and port), or its URL.
  def target = hostname ? [ hostname, port ].compact.join(":") : url

  def uptime_ratio(window) = uptime[window.to_s]

  # Link to the probe in Uptime Kuma.
  # (nil unless the instance address is http(s): never a javascript: link)
  def dashboard_url(base_url) = Integration.http_url?(base_url) ? "#{base_url.to_s.chomp("/")}/dashboard/#{monitor_id.to_i}" : nil
end
