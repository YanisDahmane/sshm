# Where a keyring key's key is installed, from the AccountSnapshots (last known
# keys of each server account), with the active temporary accesses.
class Keys::PublicKeyAccessOverview
  Access = Data.define(:server, :unix_user, :read_at, :temporary_access)

  def initialize(public_key)
    @public_key = public_key
  end

  def accesses
    temporary = TemporaryAccess.active.where(fingerprint: @public_key.fingerprint).index_by { |access| [ access.server_id, access.unix_user ] }

    AccountSnapshot.with_fingerprint(@public_key.fingerprint)
                   .sort_by { |snapshot| [ snapshot.server.name.downcase, snapshot.unix_user ] }
                   .map { |snapshot| Access.new(snapshot.server, snapshot.unix_user, snapshot.read_at, temporary[[ snapshot.server_id, snapshot.unix_user ]]) }
  end
end
