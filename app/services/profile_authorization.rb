require "shellwords"

# Authorizes a profile on a server by appending its public key to the
# authorized_keys file of the server's SSH user, unless the key is already
# there. The line's comment is the profile name, so it shows up as "known".
class ProfileAuthorization
  Result = Data.define(:status, :error_title, :error_details) do
    def success? = status != :error
    def added? = status == :added
    def already_present? = status == :already_present
  end

  def self.call(server, profile, **connection_options)
    key = profile.authorized_key
    line = "#{key.type} #{key.key} #{profile.name}"

    output = SshConnection.open(server, **connection_options) do |ssh|
      ssh.exec!("sh -c #{Shellwords.escape(append_script(line, key.key))}").stdout
    end

    Result.new(status: output.include?("present") ? :already_present : :added, error_title: nil, error_details: nil)
  rescue SshConnection::Error => e
    Result.new(status: :error, error_title: e.title, error_details: e.message)
  end

  # POSIX sh script: creates ~/.ssh (700) and authorized_keys (600) if needed,
  # prints "present" when the key blob is already in the file, otherwise
  # appends the line (adding a newline first if the file does not end with one)
  # and prints "added".
  def self.append_script(line, blob)
    <<~SH
      set -e
      umask 077
      mkdir -p "$HOME/.ssh"
      file="$HOME/.ssh/authorized_keys"
      touch "$file"
      if grep -qF -- #{Shellwords.escape(blob)} "$file"; then
        echo present
      else
        if [ -s "$file" ] && [ -n "$(tail -c 1 "$file")" ]; then echo >> "$file"; fi
        printf '%s\\n' #{Shellwords.escape(line)} >> "$file"
        echo added
      fi
    SH
  end
end
