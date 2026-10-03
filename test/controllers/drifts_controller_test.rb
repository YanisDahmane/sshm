require "test_helper"

class DriftsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include StubHelpers
  include ActionView::RecordIdentifier

  def snapshot(server, unix_user, *lines)
    AccountSnapshot.create!(server: server, unix_user: unix_user, read_at: 1.minute.ago, content: lines.join("\n"))
  end

  setup do
    AccessRule.create!(team: teams(:developers), server_group: server_groups(:production))
    @stranger = SshKeyGenerator.generate(comment: "bob@desktop")
    snapshot(servers(:web), "deploy", profiles(:ci).public_key, @stranger.public_key)
  end

  def entry_id(server, unix_user) = "#drift-#{dom_id(server)}-#{unix_user}"

  test "requires authentication" do
    get drift_path
    assert_redirected_to new_user_session_path
  end

  test "lists each covered account with its missing and extra keys" do
    sign_in users(:one)
    get drift_path

    assert_response :success
    assert_select "nav.access-tabs a[aria-current=page]", text: /Écarts/
    assert_select "nav.access-tabs .drift-count", "1"
    assert_select ".drift-summary", text: /1 compte en écart : 1 clé manquante, 1 clé en trop/
    assert_select "form[action=?] button.add-all-missing", drift_fix_path

    assert_select "#{entry_id(servers(:web), "deploy")}.is-drift" do
      assert_select ".drift-state", "Écart"
      assert_select ".drift-missing a[href=?]", profile_path(profiles(:alice)), text: "Alice"
      assert_select ".drift-missing form[action=?]", drift_fix_path do
        assert_select "input[name=server_id][value=?]", servers(:web).id.to_s
        assert_select "input[name=account][value=deploy]"
      end
      assert_select ".drift-extra li.drift-extra-key", 1 do
        assert_select "span", text: /bob@desktop/
        assert_select "form[action=?][data-confirm-variant=danger] input[name=key][value=?]", drift_fix_path, @stranger.public_key.split[1]
      end
    end
    assert_select "#{entry_id(servers(:db), "admin")}.is-unscanned .drift-state", "Jamais lu"
  end

  test "a conforming account and the empty state" do
    snapshot(servers(:db), "admin", profiles(:alice).public_key, profiles(:ci).public_key)
    sign_in users(:viewer)

    get drift_path
    assert_select "#{entry_id(servers(:db), "admin")}.is-clean .drift-state", "Conforme"
    assert_select "#drift-entries form, form[action=\"#{drift_fix_path}\"]", 0, "viewers cannot fix anything"

    AccessRule.delete_all
    get drift_path
    assert_select "p", text: "Aucune règle d'accès : il n'y a rien à comparer."
  end
end
