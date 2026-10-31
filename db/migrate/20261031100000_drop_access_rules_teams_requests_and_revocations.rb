# Elio simplifies SSH key management: access rules and drift detection, teams,
# access requests, "revoke everywhere" and non-login Unix accounts are gone.
class DropAccessRulesTeamsRequestsAndRevocations < ActiveRecord::Migration[8.1]
  REMOVED_ACTIVITY_KINDS = %w[
    access_requested access_request_approved access_request_denied profile_revoked_everywhere
    access_drift_detected access_rule_created access_rule_deleted team_created team_deleted
  ].freeze

  def up
    drop_table :access_requests
    drop_table :access_rules
    drop_table :team_memberships
    drop_table :teams
    drop_table :revocation_steps
    drop_table :revocations

    remove_reference :users, :profile, foreign_key: { on_delete: :nullify }, index: { unique: true, where: "(profile_id IS NOT NULL)" }
    remove_column :automations, :auto_fix

    execute "DELETE FROM automations WHERE kind = 'drift_check'"
    execute "DELETE FROM activities WHERE kind IN (#{REMOVED_ACTIVITY_KINDS.map { |kind| connection.quote(kind) }.join(", ")})"
    REMOVED_ACTIVITY_KINDS.each do |kind|
      execute "UPDATE notification_channels SET activity_kinds = activity_kinds - #{connection.quote(kind)}"
    end

    # Only the login account of each server is managed now.
    execute <<~SQL
      DELETE FROM account_snapshots USING servers
      WHERE account_snapshots.server_id = servers.id AND account_snapshots.unix_user <> servers.username
    SQL
    execute <<~SQL
      DELETE FROM temporary_accesses USING servers
      WHERE temporary_accesses.server_id = servers.id AND temporary_accesses.unix_user <> servers.username
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
