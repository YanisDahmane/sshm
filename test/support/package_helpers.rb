# Records an inventory of packages for a server (counts in the snapshot, list in the table).
module PackageHelpers
  def record_packages(server, packages, status: "ok")
    data = Inventory::Collectors::Packages.summarize(packages.map(&:stringify_keys))
    server.inventory_snapshots.find_or_initialize_by(category: "packages")
          .update!(status: status, data: Inventory::Collectors::Packages.snapshot_data(data), collected_at: Time.current, checked_at: Time.current)
    Inventory::Collectors::Packages.record(server, data, Time.current)
  end
end
