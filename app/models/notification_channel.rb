# A destination for activity notifications. Only Slack incoming webhooks for
# now: each channel picks the activity kinds it receives (Activity::KINDS)
# and whether messages mention @channel.
class NotificationChannel < ApplicationRecord
  KINDS = %w[slack].freeze
  SLACK_WEBHOOK = %r{\Ahttps://hooks\.slack\.com/services/[A-Za-z0-9/_-]+\z}

  encrypts :webhook_url

  normalizes :name, with: ->(value) { value.squish }
  normalizes :webhook_url, with: ->(value) { value.strip }
  normalizes :activity_kinds, with: ->(kinds) { Array(kinds).compact_blank.map(&:to_s).uniq }

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :kind, inclusion: { in: KINDS }
  validates :webhook_url, presence: true, format: { with: SLACK_WEBHOOK, allow_blank: true }
  validate :activity_kinds_must_be_known

  scope :enabled, -> { where(enabled: true) }

  # Enabled channels that receive this kind of activity.
  def self.subscribed_to(kind)
    enabled.where("activity_kinds @> ?", [ kind.to_s ].to_json)
  end

  def subscribed_to?(kind) = activity_kinds.include?(kind.to_s)

  # Webhook shown in the UI: the secret part is hidden.
  def masked_webhook_url = webhook_url.to_s.sub(%r{/services/(.{4}).*}, '/services/\1…')

  def record_delivery!(error: nil)
    update_columns(error ? { last_error: error } : { last_delivered_at: Time.current, last_error: nil })
  end

  private

  def activity_kinds_must_be_known
    unknown = activity_kinds - Activity::KINDS.keys.map(&:to_s)
    errors.add(:activity_kinds, :inclusion) if unknown.any?
  end
end
