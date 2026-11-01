# Result of a KeyRotation on one server; `phase` tells where it failed
# (install, verify or cleanup).
class KeyRotationStep < ApplicationRecord
  PHASES = { "install" => "installation de la nouvelle clé", "verify" => "connexion avec la nouvelle clé", "cleanup" => "retrait de l'ancienne clé" }.freeze

  belongs_to :key_rotation
  belongs_to :server, optional: true

  enum :status, { rotated: "rotated", failed: "failed" }, validate: true

  def phase_label = PHASES.fetch(phase, phase)
end
