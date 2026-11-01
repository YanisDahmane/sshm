# What a registry serves for an image tag (ImageRegistry::UpdateCheck): its
# current digest, compared with the digest of the image pulled on a server.
class ImageUpdate < ApplicationRecord
  # Checked again after this delay (registries limit their requests).
  FRESHNESS = 6.hours

  scope :stale, -> { where(checked_at: nil).or(where(checked_at: ...FRESHNESS.ago)) }

  # Update state of a Docker image of the inventory ({ "tags", "digests" }):
  # :available, :current, :unknown (not checked, error, no tag or digest).
  def self.state_for(image, updates)
    reference = Array(image["tags"]).first
    update = reference && updates[reference]
    digests = Array(image["digests"]).map { |digest| digest.split("@").last }
    return :unknown unless update&.remote_digest && digests.any?

    digests.include?(update.remote_digest) ? :current : :available
  end

  # { reference => ImageUpdate } for the images of the given docker inventories.
  def self.for_images(images) = where(reference: images.filter_map { |image| Array(image["tags"]).first }.uniq).index_by(&:reference)
end
