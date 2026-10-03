require "shellwords"

# Authorizes a profile on a server by appending its public key to the
# authorized_keys file of an account (see AuthorizedKeysAccount), unless the
# key is already there. The line's comment is the profile name, so it shows
# up as "known".
class ProfileAuthorization
  Result = Data.define(:status, :error_title, :error_details) do
    def success? = status != :error
    def added? = status == :added
    def already_present? = status == :already_present
  end

  def self.call(server, profile, account: nil, **connection_options)
    account ||= AuthorizedKeysAccount.login(server)
    key = profile.authorized_key
    line = "#{key.type} #{key.key} #{profile.name}"
    script = append_script(line, key.key, home: account.home, owner: account.owner)

    output = SshConnection.open(server, **connection_options) { |ssh| ssh.exec!(account.command(script)).stdout }

    Result.new(status: output.include?("present") ? :already_present : :added, error_title: nil, error_details: nil)
  rescue SshConnection::Error => e
    title, details = account.error_for(e)
    Result.new(status: :error, error_title: title, error_details: details)
  end

  # POSIX sh script: creates <home>/.ssh (700) and authorized_keys (600) if
  # needed (owned by `owner` when given), prints "present" when the key blob
  # is already in the file, otherwise appends the line (adding a newline first
  # if the file does not end with one) and prints "added".
  def self.append_script(line, blob, home: "$HOME", owner: nil)
    owner = Shellwords.escape(owner) if owner

    AuthorizedKeysScript.prelude(home) + <<~SH
      umask 077
      mkdir -p "$home/.ssh"
      file="$home/.ssh/authorized_keys"
      touch "$file"
      #{%(chown "#{owner}:$(id -gn #{owner})" "$home/.ssh" "$file") if owner}
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
