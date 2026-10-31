# Records an inventory of ports (from a recorded output) and of containers.
module PortHelpers
  def record_ports(server, name = :debian12, firewall: nil)
    data = Inventory::Collectors::Ports.parse(file_fixture("inventory/ports/#{name}.txt").read.split(/^@@elio (\S+)\n/).drop(1).each_slice(2).to_h)
    data["firewall"] = firewall if firewall
    server.inventory_snapshots.create!(category: "ports", status: "ok", data: data, collected_at: Time.current, checked_at: Time.current)
  end

  def record_containers(server, containers)
    server.inventory_snapshots.create!(category: "services", status: "ok", data: { "units" => [], "containers" => containers, "docker" => "ok" },
                                       collected_at: Time.current, checked_at: Time.current)
  end
end
