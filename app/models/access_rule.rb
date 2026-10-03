# Desired state: "this profile (or every profile of this team) must have
# access to this server (or every server of this group)", on the login user
# of each server (unix_user nil) or on a named account. Permanent accesses
# only. DriftDetector compares the rules with the keys read on the servers.
class AccessRule < ApplicationRecord
  belongs_to :profile, optional: true
  belongs_to :team, optional: true
  belongs_to :server, optional: true
  belongs_to :server_group, optional: true
  belongs_to :created_by, class_name: "User", optional: true

  normalizes :unix_user, with: ->(value) { value.strip.presence }

  validate :exactly_one_subject_and_target
  validates :unix_user, format: { with: AuthorizedKeysAccount::USERNAME_FORMAT }, allow_nil: true
  validate :must_be_new

  # "profile:12" / "team:3" and "server:4" / "server_group:2", as sent by the form.
  def subject_key = profile_id ? "profile:#{profile_id}" : (team_id && "team:#{team_id}")
  def target_key = server_id ? "server:#{server_id}" : (server_group_id && "server_group:#{server_group_id}")

  def subject_key=(value)
    type, id = value.to_s.split(":", 2)
    self.profile_id = (id if type == "profile")
    self.team_id = (id if type == "team")
  end

  def target_key=(value)
    type, id = value.to_s.split(":", 2)
    self.server_id = (id if type == "server")
    self.server_group_id = (id if type == "server_group")
  end

  def subject = profile || team
  def target = server || server_group

  def profiles = profile ? [ profile ] : team.profiles.to_a
  def servers = server ? [ server ] : server_group.servers.to_a

  def account_for(server) = unix_user ? AuthorizedKeysAccount.for(server, unix_user) : AuthorizedKeysAccount.login(server)

  def account_label = unix_user || "utilisateur SSH"

  def summary = "#{subject.name} → #{target.name} (#{account_label})"

  # Expected keys of every account covered by the rules:
  # { [server, unix_user] => { fingerprint => profile } }.
  def self.expectations(rules = includes(:profile, :server, team: :profiles, server_group: :servers))
    rules.each_with_object(Hash.new { |hash, key| hash[key] = {} }) do |rule, expected|
      rule.servers.each do |server|
        account = rule.account_for(server)
        rule.profiles.each { |profile| expected[[ server, account.unix_user ]][profile.fingerprint] = profile }
      end
    end
  end

  private

  def exactly_one_subject_and_target
    errors.add(:subject_key, :blank) unless [ profile_id, team_id ].compact.one?
    errors.add(:target_key, :blank) unless [ server_id, server_group_id ].compact.one?
  end

  def must_be_new
    duplicate = AccessRule.where(profile_id: profile_id, team_id: team_id, server_id: server_id, server_group_id: server_group_id, unix_user: unix_user)
    errors.add(:base, :duplicate_rule) if duplicate.where.not(id: id).exists?
  end
end
