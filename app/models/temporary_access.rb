# A key authorized on a server account for a limited time. The authorized_keys
# line carries an OpenSSH `expiry-time` option, so sshd refuses the key once
# expired even if the app is down; ExpireTemporaryAccessJob then removes the
# line and ends the access. At most one active access per server, account and key.
class TemporaryAccess < ApplicationRecord
  # Choices offered in the UI: param value (minutes) => [label, duration].
  DURATIONS = {
    "10" => [ "10 minutes", 10.minutes ],
    "30" => [ "30 minutes", 30.minutes ],
    "60" => [ "1 heure", 1.hour ],
    "240" => [ "4 heures", 4.hours ],
    "1440" => [ "1 jour", 1.day ],
    "10080" => [ "7 jours", 7.days ]
  }.freeze

  belongs_to :server
  belongs_to :profile, optional: true

  validates :unix_user, :key_blob, :fingerprint, :expires_at, presence: true

  scope :active, -> { where(ended_at: nil) }
  scope :expired, -> { active.where(expires_at: ..Time.current) }

  def self.duration_for(param)
    DURATIONS.fetch(param.to_s) { raise ArgumentError, "Unknown duration: #{param.inspect}" }.last
  end

  def self.label_for(duration)
    DURATIONS.values.find { |_label, value| value == duration }&.first || ActiveSupport::Duration.build(duration).inspect
  end

  def account = AuthorizedKeysAccount.for(server, unix_user)

  def active? = ended_at.nil?

  def expired? = expires_at <= Time.current

  def end!
    update!(ended_at: Time.current) if active?
  end
end
