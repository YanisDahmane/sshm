require "test_helper"

class SettingsUsersTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "lists the users and the pending invitations with their link" do
    invitation = Invitation.create!(email: "dave@example.com", role: :operator, invited_by: users(:one))
    Invitation.create!(email: "old@example.com", invited_by: users(:one)).revoke!
    sign_in users(:one)

    get settings_users_path

    assert_select "#users li.user-row", 3
    assert_select "#users li", text: /one@example.com \(vous\)/
    assert_select "li.pending-invitation", 1 do
      assert_select "p", text: /dave@example.com\s+Opérateur/
      assert_select "input.invitation-link[value=?]", invitation_acceptance_url(invitation.token)
      assert_select "form[action=?][data-turbo-confirm]", settings_invitation_path(invitation)
    end
  end

  test "an admin invites someone" do
    sign_in users(:one)

    post settings_invitations_path, params: { invitation: { email: "Dave@example.com", role: "operator" } }

    invitation = Invitation.sole
    assert_equal [ "dave@example.com", "operator", users(:one) ], [ invitation.email, invitation.role, invitation.invited_by ]
    assert_redirected_to settings_users_path
    assert_equal "Invitation créée pour dave@example.com. Copiez le lien et envoyez-le-lui.", flash[:notice]
    assert_equal "dave@example.com invité (Opérateur)", Activity.of_kind(:user_invited).sole.summary
  end

  test "an invalid invitation is explained" do
    sign_in users(:one)

    post settings_invitations_path, params: { invitation: { email: "operator@example.com", role: "viewer" } }

    assert_equal 0, Invitation.count
    assert_match "correspond déjà à un utilisateur", flash[:alert]
  end

  test "an admin revokes a pending invitation" do
    invitation = Invitation.create!(email: "dave@example.com", invited_by: users(:one))
    sign_in users(:one)

    delete settings_invitation_path(invitation)

    assert_equal :revoked, invitation.reload.status
    assert_redirected_to settings_users_path
    assert_equal "Invitation de dave@example.com révoquée", Activity.of_kind(:invitation_revoked).sole.summary
  end

  test "an invitation that is no longer pending cannot be revoked" do
    invitation = Invitation.create!(email: "dave@example.com", invited_by: users(:one)).tap(&:revoke!)
    sign_in users(:one)

    delete settings_invitation_path(invitation)

    assert_response :not_found
  end
end
