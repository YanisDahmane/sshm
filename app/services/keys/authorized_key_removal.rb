# Removes a public key from the authorized_keys file of an account (see
# AuthorizedKeysAccount). The protected keys (Elio's, by default) are refused:
# every line whose key blob is `blob` is dropped, other lines (comments,
# other keys) are kept byte for byte. The Elio key can never be removed,
# since the app would lose access to the server.
class Keys::AuthorizedKeyRemoval
  BLOB_FORMAT = %r{\A[A-Za-z0-9+/]+={0,2}\z}

  Result = Data.define(:status, :error_title, :error_details) do
    def success? = %i[removed absent].include?(status)
    def removed? = status == :removed
    def absent? = status == :absent
  end

  def self.call(server, blob, account: nil, protected_keys: SshKey.app_keys, **connection_options)
    account ||= AuthorizedKeysAccount.login(server)
    return error("Clé invalide", "La clé à supprimer n'est pas une clé publique valide.") unless blob.to_s.match?(BLOB_FORMAT)
    return error("Suppression interdite", "La clé Elio ne peut pas être supprimée : l'application perdrait l'accès au serveur.") if Array(protected_keys).any? { |key| key.blob == blob }

    output = Ssh::Connection.open(server, **connection_options) do |ssh|
      ssh.run_command!("keys.remove", blob: blob).stdout
    end

    Result.new(status: output.include?("removed") ? :removed : :absent, error_title: nil, error_details: nil)
  rescue Ssh::Connection::Error => e
    error(*account.error_for(e))
  end

  # The command sent (config/ssh_commands.yml: keys.remove), also run locally by the tests.
  def self.command(blob) = Ssh::Commands.render("keys.remove", blob: blob)

  def self.error(title, details)
    Result.new(status: :error, error_title: title, error_details: details)
  end
  private_class_method :error
end
