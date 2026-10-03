require "shellwords"

# Removes a public key from the authorized_keys file of an account (see
# AuthorizedKeysAccount). The protected keys (SSHM's, by default) are refused:
# every line whose key blob is `blob` is dropped, other lines (comments,
# other keys) are kept byte for byte. The SSHM key can never be removed,
# since the app would lose access to the server.
class AuthorizedKeyRemoval
  BLOB_FORMAT = %r{\A[A-Za-z0-9+/]+={0,2}\z}

  Result = Data.define(:status, :error_title, :error_details) do
    def success? = %i[removed absent].include?(status)
    def removed? = status == :removed
    def absent? = status == :absent
  end

  def self.call(server, blob, account: nil, protected_keys: SshKey.app_keys, **connection_options)
    account ||= AuthorizedKeysAccount.login(server)
    return error("Clé invalide", "La clé à supprimer n'est pas une clé publique valide.") unless blob.to_s.match?(BLOB_FORMAT)
    return error("Suppression interdite", "La clé SSHM ne peut pas être supprimée : l'application perdrait l'accès au serveur.") if Array(protected_keys).any? { |key| key.blob == blob }

    output = SshConnection.open(server, **connection_options) do |ssh|
      ssh.exec!(account.command(remove_script(blob, home: account.home))).stdout
    end

    Result.new(status: output.include?("removed") ? :removed : :absent, error_title: nil, error_details: nil)
  rescue SshConnection::Error => e
    error(*account.error_for(e))
  end

  # POSIX sh script: prints "absent" when no line holds the blob as one of
  # its fields, otherwise rewrites the file in place (keeping its owner and
  # permissions) without those lines and prints "removed".
  def self.remove_script(blob, home: "$HOME")
    blob = Shellwords.escape(blob)

    AuthorizedKeysScript.prelude(home) + <<~SH
      file="$home/.ssh/authorized_keys"
      if [ ! -f "$file" ]; then echo absent; exit 0; fi
      matches=$(awk -v blob=#{blob} '{ for (i = 1; i <= NF; i++) if ($i == blob) { n++; break } } END { print n + 0 }' "$file")
      if [ "$matches" -eq 0 ]; then echo absent; exit 0; fi
      #{AuthorizedKeysScript.drop_lines(blob)}
      echo removed
    SH
  end

  def self.error(title, details)
    Result.new(status: :error, error_title: title, error_details: details)
  end
  private_class_method :error
end
