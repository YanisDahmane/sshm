# What needs attention on the fleet, most serious first, for the "À traiter"
# list of the overview: unreachable servers, health concerns (or a refused
# Elio key), unknown keys, pending security updates, servers never inventoried.
# Servers must come with their inventory snapshots loaded.
class AttentionList
  Item = Data.define(:tone, :icon, :subject, :text, :action, :path)

  TONE_ORDER = { "crit" => 0, "warn" => 1, "info" => 2 }.freeze

  def initialize(servers, insights:, summary:, routes: Rails.application.routes.url_helpers)
    @servers = servers.to_a
    @insights = insights
    @summary = summary
    @routes = routes
  end

  def items
    @items ||= (server_items + fleet_items).sort_by { |item| [ TONE_ORDER.fetch(item.tone), item.subject ] }
  end

  def any? = items.any?

  private

  def server_items
    @servers.flat_map do |server|
      items = []
      if server.health_state == "off"
        items << Item.new("crit", :signal_slash, server.name, "Ne répond plus sur son port SSH", "Voir", @routes.server_path(server))
      elsif (reasons = Array(server.health_reasons)).any?
        first = reasons.first
        more = reasons.size > 1 ? " (+#{reasons.size - 1})" : ""
        items << Item.new(first["tone"], first["tone"] == "crit" ? :x_mark : :exclamation_triangle, server.name, "#{first["text"]}#{more}", "Voir", @routes.server_path(server))
      elsif server.ssh_ok == false
        items << Item.new("crit", :key, server.name, "La clé d'Elio est refusée : rien ne peut être lu", "Installer la clé", @routes.server_path(server))
      end
      if (orphans = @insights.orphans_by_server_id[server.id]).present?
        items << Item.new("warn", :key, server.name, "#{orphans.size} clé#{"s" if orphans.size > 1} hors trousseau", "Voir les clés", @routes.server_path(server, tab: "keys"))
      end
      if server.inventoried_at.nil? && server.ssh_ok
        items << Item.new("info", :pulse, server.name, "Pas encore d'inventaire", "Voir", @routes.server_path(server))
      end
      items
    end
  end

  def fleet_items
    return [] unless @summary.security_updates.positive?

    servers = @summary.servers_with_security_updates
    [ Item.new("warn", :shield_check, "#{servers} serveur#{"s" if servers > 1}", "#{@summary.security_updates} mise(s) à jour de sécurité en attente",
               "Voir les paquets", @routes.packages_path) ]
  end
end
