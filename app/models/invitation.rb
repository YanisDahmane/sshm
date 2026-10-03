# Invitation to join SSHM with a role, accepted through a single-use link
# (/invitations/:token) valid for VALIDITY. The token is encrypted
# (deterministic, so it can be looked up) and kept so admins can copy the
# link again while the invitation is pending.
class Invitation < ApplicationRecord
  VALIDITY = 7.days

  belongs_to :invited_by, class_name: "User"
  belongs_to :user, optional: true

  encrypts :token, deterministic: true

  normalizes :email, with: ->(value) { value.strip.downcase }

  enum :role, User.roles, default: :viewer, validate: true

  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP, allow_blank: true }
  validate :email_must_be_free, on: :create

  before_validation(on: :create) do
    self.token ||= SecureRandom.urlsafe_base64(32)
    self.expires_at ||= VALIDITY.from_now
  end

  scope :pending, -> { where(accepted_at: nil, revoked_at: nil).where(expires_at: Time.current..) }

  def self.find_pending_by_token(token)
    invitation = find_by(token: token.to_s) if token.present?
    invitation if invitation&.pending?
  end

  def pending? = accepted_at.nil? && revoked_at.nil? && !expired?

  def expired? = expires_at <= Time.current

  def status
    if accepted_at then :accepted
    elsif revoked_at then :revoked
    elsif expired? then :expired
    else :pending
    end
  end

  def role_label = User::ROLE_LABELS.fetch(role)

  # Creates the account with the invitation's email and role.
  def accept!(password:, password_confirmation:)
    raise ActiveRecord::RecordInvalid, self unless pending?

    transaction do
      account = User.create!(email: email, role: role, password: password, password_confirmation: password_confirmation)
      update!(user: account, accepted_at: Time.current)
      account
    end
  end

  def revoke!
    update!(revoked_at: Time.current) if pending?
  end

  private

  def email_must_be_free
    if User.exists?(email: email)
      errors.add(:email, :taken_by_user)
    elsif Invitation.pending.exists?(email: email)
      errors.add(:email, :already_invited)
    end
  end
end
