# Display of the Uptime Kuma probes (UptimeKumaMonitor).
module UptimeKumaHelper
  MONITOR_STATES = { "up" => [ :good, "En ligne" ], "down" => [ :crit, "Hors ligne" ], "pending" => [ :warn, "En attente" ],
                     "maintenance" => [ :neutral, "Maintenance" ], "unknown" => [ :neutral, "Inconnu" ] }.freeze

  def monitor_status_badge(monitor)
    tone, label = MONITOR_STATES.fetch(monitor.state)
    status_badge(tone, label, class: "monitor-status", data: { state: monitor.state })
  end

  # 0.99625 → "99,63 %"
  def uptime_percent(ratio)
    return tag.span("—", class: "text-ink-3") unless ratio

    percent = ratio * 100
    text = "#{format(percent >= 99.995 ? "%.0f" : "%.2f", percent).sub(".", ",")} %"
    tag.span(text, class: "tabular-nums #{percent < 99 ? "text-warn-ink" : ""}")
  end

  # Which address of the server the probe reaches: "10.8.0.100 · wg0 (WireGuard)".
  def monitor_via(monitor)
    return unless monitor.server

    address = monitor.matched_address || (monitor.hostname if Inventory::IpScope.ip?(monitor.hostname))
    interface = address && Array(monitor.server.inventory("network")&.data&.dig("addresses")).find { |entry| entry["address"] == address }
    return if address.nil? || (interface.nil? && address == monitor.hostname) # (nothing more than the target)

    [ address, (interface && "#{interface["interface"]} (#{network_kind_label(interface["kind"])})") ].compact.join(" · ")
  end

  def monitor_match_label(monitor) = UptimeKumaMonitor::MATCHES[monitor.matched_by]

  # Probes attached by hand (to a server or to none), read once per page.
  def manual_monitor_ids
    @manual_monitor_ids ||= IntegrationLink.joins(:integration).where(integrations: { kind: "uptime_kuma" }).pluck(:external_id).to_set
  end
end
