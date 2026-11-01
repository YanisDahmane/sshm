# Services of a server: systemd units (state, enabled at boot) and Docker
# containers with their Compose project, read from the labels Docker Compose
# sets (no need to parse the compose files). Docker needs the docker group or
# root: without them the collection is partial.
class Inventory::Collectors::Services < Inventory::Collector
  LABELS = %w[com.docker.compose.project com.docker.compose.project.working_dir com.docker.compose.project.config_files com.docker.compose.service].freeze

  def collect
    result = run("inventory.services")
    raise Error, "Lecture des services impossible : #{result.stderr.strip.presence || "code #{result.exit_status}"}" if result.stdout.blank?

    sections = self.class.sections(result.stdout)
    units = self.class.parse_units(sections["units"].to_s, self.class.parse_unit_files(sections["unit-files"].to_s))
    docker_present = sections["docker"].to_s.strip == "present"
    return unsupported("Ni systemd ni Docker sur ce système") if units.nil? && !docker_present

    data = { "units" => units || [], "containers" => [], "docker" => (docker_present ? "ok" : "absent") }
    if docker_present
      containers = run("inventory.docker_containers")
      return partial(data.merge("docker" => "unreadable"), "Conteneurs Docker illisibles : #{containers.stderr.strip.truncate(120)}") unless containers.success?

      data["containers"] = self.class.parse_containers(containers.stdout)
    end
    ok(data)
  end

  # "ssh.service loaded active running OpenBSD Secure Shell server"; nil without systemd.
  def self.parse_units(text, enabled)
    return if text.strip == "unsupported"

    text.lines.filter_map do |line|
      name, load, active, sub, *description = line.split
      next unless name&.end_with?(".service") && sub

      { "name" => name, "load" => load, "active" => active, "sub" => sub, "description" => description.join(" ").presence,
        "enabled" => enabled[name] }.compact
    end
  end

  # "ssh.service enabled enabled"
  def self.parse_unit_files(text)
    text.lines.filter_map { |line| line.split.first(2).then { |name, state| [ name, state ] if name&.end_with?(".service") && state } }.to_h
  end

  def self.parse_containers(text)
    text.lines.filter_map do |line|
      id, name, image, state, status, ports, project, working_dir, config_files, service = line.chomp.split("\t", -1)
      next if name.blank?

      { "id" => id.to_s.first(12), "name" => name, "image" => image, "state" => state, "status" => status, "ports" => ports.presence,
        "project" => project.presence, "working_dir" => working_dir.presence,
        "config_files" => config_files.to_s.split(",").map(&:strip).presence, "service" => service.presence }.compact
    end
  end

  def self.changes(previous, data)
    failed = ->(units) { Array(units).select { |unit| unit["active"] == "failed" }.map { |unit| unit["name"] }.to_set }
    running = ->(containers) { Array(containers).select { |container| container["state"] == "running" }.map { |container| container["name"] }.to_set }
    known_containers = Array(data["containers"]).map { |container| container["name"] }.to_set

    newly_failed = failed.(data["units"]) - failed.(previous["units"])
    recovered = failed.(previous["units"]) - failed.(data["units"])
    recovered &= Array(data["units"]).map { |unit| unit["name"] }.to_set
    stopped = (running.(previous["containers"]) - running.(data["containers"])) & known_containers
    started = (running.(data["containers"]) - running.(previous["containers"])) & Array(previous["containers"]).map { |container| container["name"] }.to_set

    newly_failed.sort.map { |name| { kind: :service_failed, data: { service: name } } } +
      recovered.sort.map { |name| { kind: :service_recovered, data: { service: name } } } +
      (data["docker"] == "ok" ? stopped.sort.map { |name| { kind: :container_stopped, data: { container: name } } } +
                                started.sort.map { |name| { kind: :container_started, data: { container: name } } } : [])
  end
end
