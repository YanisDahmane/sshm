class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

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

  def can?(permission) = PERMISSIONS.fetch(permission).include?(role)

  def role_label = ROLE_LABELS.fetch(role)
end
