# Checks that the app can open an SSH session on a server and run a command,
# by echoing a random token and comparing the output.
class Ssh::Check
  Result = Data.define(:success, :message, :details, :reason, :host_key) do
    def initialize(success:, message:, details:, reason: nil, host_key: nil) = super
    def success? = success
  end

  def self.call(server, **connection_options)
    token = "elio-check-#{SecureRandom.hex(4)}"
    output = Ssh::Connection.open(server, **connection_options) { |ssh| ssh.exec!("echo #{token}").stdout.strip }

    if output == token
      Result.new(success: true, message: "Connexion SSH réussie", details: "#{server.username}@#{server.host} a répondu à `echo #{token}`.")
    else
      Result.new(success: false, message: "Réponse inattendue du serveur", details: "Attendu « #{token} », reçu « #{output.truncate(200)} ».")
    end
  rescue Ssh::Connection::Error => e
    host_key = { new: e.new_fingerprint, known: e.known_fingerprints } if e.is_a?(Ssh::Connection::HostKeyMismatchError)
    Result.new(success: false, message: e.title, details: e.message, reason: e.reason, host_key: host_key)
  end
end
