# A user asks for temporary access to a server account with their own profile
# (users.profile_id), with a reason. An operator or admin other than the
# requester approves it (→ temporary AccessGrant) or denies it. A request left
# pending for PENDING_FOR expires.
class AccessRequest < ApplicationRecord
  PENDING_FOR = 24.hours
  STATUSES = { "pending" => "En attente", "approved" => "Acceptée", "denied" => "Refusée", "expired" => "Expirée", "cancelled" => "Annulée" }.freeze

  belongs_to :requester, class_name: "User"
  belongs_to :profile, optional: true
  belongs_to :server
  belongs_to :decided_by, class_name: "User", optional: true

  normalizes :reason, :decision_note, with: ->(value) { value.strip.presence }
  normalizes :unix_user, with: ->(value) { value.strip }

  validates :status, inclusion: { in: STATUSES.keys }
  validates :unix_user, format: { with: AuthorizedKeysAccount::USERNAME_FORMAT }
  validates :duration_minutes, inclusion: { in: TemporaryAccess::DURATIONS.keys.map(&:to_i) }
  validates :reason, presence: true, length: { maximum: 500 }
  validates :decision_note, length: { maximum: 500 }
  validate :requester_must_have_a_profile, on: :create

  before_validation :default_account, on: :create

  scope :pending, -> { where(status: "pending") }
  scope :recent, -> { order(created_at: :desc, id: :desc) }

  # Marks as expired the pending requests nobody decided on in time.
  def self.expire_stale!
    pending.where(created_at: ...PENDING_FOR.ago).update_all(status: "expired", updated_at: Time.current)
  end

  def pending? = status == "pending"
  def status_label = STATUSES.fetch(status)
  def duration = duration_minutes.minutes
  def duration_label = TemporaryAccess.label_for(duration)
  def account = AuthorizedKeysAccount.for(server, unix_user)
  def expires_at = created_at + PENDING_FOR

  # Nobody approves their own request.
  def decidable_by?(user) = pending? && user.can?(:operate) && user != requester

  def approve!(user)
    update!(status: "approved", decided_by: user, decided_at: Time.current)
  end

  def deny!(user, note)
    update!(status: "denied", decided_by: user, decided_at: Time.current, decision_note: note)
  end

  def cancel!
    update!(status: "cancelled")
  end

  private

  def default_account
    self.profile ||= requester&.profile
    self.unix_user = server.username if unix_user.blank? && server
  end

  def requester_must_have_a_profile
    errors.add(:base, :no_profile) unless profile
  end
end
