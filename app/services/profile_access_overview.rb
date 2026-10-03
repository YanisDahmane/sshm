# Where a profile's key is installed, from the AccountSnapshots (last known
# keys of each server account), with the active temporary accesses.
class ProfileAccessOverview
  Access = Data.define(:server, :unix_user, :read_at, :temporary_access)

  def initialize(profile)
    @profile = profile
  end

  def accesses
    temporary = TemporaryAccess.active.where(fingerprint: @profile.fingerprint).index_by { |access| [ access.server_id, access.unix_user ] }

    AccountSnapshot.with_fingerprint(@profile.fingerprint)
                   .sort_by { |snapshot| [ snapshot.server.name.downcase, snapshot.unix_user ] }
                   .map { |snapshot| Access.new(snapshot.server, snapshot.unix_user, snapshot.read_at, temporary[[ snapshot.server_id, snapshot.unix_user ]]) }
  end
end
