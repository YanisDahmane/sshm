# The host keys pinned by SshConnection (TOFU) in SshConnection::KNOWN_HOSTS_FILE.
module KnownHosts
  # Removes the entries of host:port, written by net-ssh as "host" (port 22)
  # or "[host]:port". Returns the number of removed lines.
  def self.forget(host, port, file: SshConnection::KNOWN_HOSTS_FILE)
    file = Pathname(file)
    return 0 unless file.exist?

    names = port.to_i == 22 ? [ host, "[#{host}]:22" ] : [ "[#{host}]:#{port}" ]
    lines = file.readlines
    kept = lines.reject { |line| (line.split.first.to_s.split(",") & names).any? }
    file.write(kept.join) if kept.size != lines.size
    lines.size - kept.size
  end
end
