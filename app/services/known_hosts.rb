# The host keys pinned by SshConnection (trust on first use), in `file`
# (SshConnection::KNOWN_HOSTS_FILE by default, replaced in tests).
module KnownHosts
  class << self
    attr_writer :file

    def file = Pathname(@file || SshConnection::KNOWN_HOSTS_FILE)

    # Removes the entries of host:port. Returns the number of removed lines.
    def forget(host, port, file: self.file)
      file = Pathname(file)
      return 0 unless file.exist?

      lines = file.readlines
      kept = lines.reject { |line| entry_for?(line, host, port) }
      file.write(kept.join) if kept.size != lines.size
      lines.size - kept.size
    end

    # SHA256 fingerprints ("SHA256:…", like `ssh-keygen -l`) pinned for host:port.
    def fingerprints(host, port, file: self.file)
      file = Pathname(file)
      return [] unless file.exist?

      file.readlines.select { |line| entry_for?(line, host, port) }.filter_map do |line|
        blob = line.split[2]
        SshKeyGenerator.fingerprint(Base64.strict_decode64(blob)) if blob
      rescue ArgumentError
        nil
      end
    end

    private

    # net-ssh writes "host" for port 22 and "[host]:port" otherwise.
    def entry_for?(line, host, port)
      names = port.to_i == 22 ? [ host, "[#{host}]:22" ] : [ "[#{host}]:#{port}" ]
      (line.split.first.to_s.split(",") & names).any?
    end
  end
end
