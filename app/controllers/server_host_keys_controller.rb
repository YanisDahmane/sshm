# Trusting the new host key of a server (reinstalled…), admins only. Only the
# fingerprint the admin was shown is accepted: the old pin is forgotten, the
# server is contacted again, and the new pin is kept only if it matches.
class ServerHostKeysController < ApplicationController
  require_permission :administer

  def create
    server = Server.find(params[:server_id])
    expected = params.expect(:fingerprint)
    previous = Ssh::KnownHosts.fingerprints(server.host, server.port)

    Ssh::KnownHosts.forget(server.host, server.port)
    Ssh::Check.call(server) # pins whatever the server presents (accept_new)

    if Ssh::KnownHosts.fingerprints(server.host, server.port).include?(expected)
      Activity.record!(:host_key_changed, server: server, new_fingerprint: expected, previous_fingerprints: previous)
      redirect_to server_path(server), notice: "Nouvelle empreinte acceptée pour « #{server.name} »."
    else
      Ssh::KnownHosts.forget(server.host, server.port)
      redirect_to server_path(server), alert: "Le serveur ne présente plus l'empreinte affichée (#{expected}) : rien n'a été accepté. Vérifiez le serveur avant de réessayer."
    end
  end
end
