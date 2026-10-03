class User < ApplicationRecord
  # No public sign up: the first admin is created through SetupsController,
  # everyone else through an Invitation.
  devise :database_authenticatable, :recoverable, :rememberable, :validatable, :trackable

  include TwoFactorAuthenticatable

  ROLE_LABELS = { "admin" => "Admin", "operator" => "Opérateur", "viewer" => "Lecture" }.freeze

  # What each permission level allows (see Authorization):
  # - view: see everything (dashboard, servers, keys, profiles, activity)
  # - operate: + manage servers and profiles, grant / revoke keys, scan
  # - administer: + settings (SSHM key, notifications, automations, users)
  PERMISSIONS = {
    view: %w[admin operator viewer],
    operate: %w[admin operator],
    administer: %w[admin]
  }.freeze

  enum :role, { admin: "admin", operator: "operator", viewer: "viewer" }, default: :viewer, validate: true

  # The person's own profile (their SSH key), e.g. to request accesses.
  belongs_to :profile, optional: true

  validates :profile_id, uniqueness: true, allow_nil: true
  validate :must_keep_an_active_admin, on: :update

  scope :active, -> { where(deactivated_at: nil) }

  def can?(permission) = PERMISSIONS.fetch(permission).include?(role)

  def role_label = ROLE_LABELS.fetch(role)

  def deactivated? = deactivated_at.present?

  # Admins must enable 2FA when the setting requires it (see ApplicationController).
  def two_factor_required? = admin? && !two_factor_enabled? && AppSetting.current.require_admin_two_factor

  def deactivate! = update!(deactivated_at: Time.current)

  def reactivate! = update!(deactivated_at: nil)

  # Devise: a deactivated account cannot sign in, and is signed out on its next request.
  def active_for_authentication? = super && !deactivated?

  def inactive_message = deactivated? ? :deactivated : super

  private

  # The last active admin can neither lose the role nor be deactivated.
  def must_keep_an_active_admin
    was_active_admin = role_was == "admin" && deactivated_at_was.nil?
    still_active_admin = admin? && !deactivated?
    return unless was_active_admin && !still_active_admin
    return if User.active.admin.where.not(id: id).exists?

    errors.add(:base, :last_admin)
  end
end
