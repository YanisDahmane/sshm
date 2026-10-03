require "test_helper"

class ServerAuthorizationsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include ActionView::RecordIdentifier
  include StubHelpers
  include TcpHelpers

  def result(status, title: nil, details: nil)
    ProfileAuthorization::Result.new(status: status, error_title: title, error_details: details)
  end

  test "requires authentication" do
    post server_authorizations_path(servers(:web)), params: { profile_id: profiles(:alice).id }
    assert_redirected_to new_user_session_path
  end

  test "returns 404 for an unknown server or profile" do
    sign_in users(:one)
    post server_authorizations_path(server_id: 0), params: { profile_id: profiles(:alice).id }
    assert_response :not_found

    sign_in users(:one)
    post server_authorizations_path(servers(:web)), params: { profile_id: 0 }
    assert_response :not_found
  end

  test "requires a profile" do
    sign_in users(:one)
    post server_authorizations_path(servers(:web))
    assert_response :bad_request
  end

  test "authorizes the profile and reloads the key list over Turbo Stream" do
    sign_in users(:one)

    stub_method(ProfileAuthorization, :call, result(:added)) do
      post server_authorizations_path(servers(:web)), params: { profile_id: profiles(:alice).id }, as: :turbo_stream
    end

    assert_response :success
    assert_turbo_stream action: :replace, target: dom_id(servers(:web), :authorized_keys) do
      assert_select "turbo-frame[loading=eager][src=?]", server_authorized_keys_path(servers(:web), account: "deploy")
    end
    assert_turbo_stream action: :update, target: "flash" do
      assert_select "div", text: "Le profil « Alice » est maintenant autorisé sur « Web » pour deploy."
    end
  end

  test "reports a profile that was already authorized" do
    sign_in users(:one)

    stub_method(ProfileAuthorization, :call, result(:already_present)) do
      post server_authorizations_path(servers(:web)), params: { profile_id: profiles(:alice).id }, as: :turbo_stream
    end

    assert_turbo_stream action: :update, target: "flash" do
      assert_select "div", text: "Le profil « Alice » était déjà autorisé sur « Web » pour deploy."
    end
  end

  test "shows the error as an alert" do
    Server.update_all(host: "127.0.0.1", port: closed_port)
    sign_in users(:one)

    post server_authorizations_path(servers(:web)), params: { profile_id: profiles(:alice).id }, as: :turbo_stream

    assert_turbo_stream action: :update, target: "flash" do
      assert_select "div.bg-red-50", text: /Impossible d'autoriser « Alice » sur « Web » pour deploy : Connexion impossible/
    end
  end

  test "the HTML fallback redirects to the server page" do
    sign_in users(:one)

    stub_method(ProfileAuthorization, :call, result(:added)) do
      post server_authorizations_path(servers(:web)), params: { profile_id: profiles(:alice).id }
    end

    assert_redirected_to server_path(servers(:web))
    assert_equal "Le profil « Alice » est maintenant autorisé sur « Web » pour deploy.", flash[:notice]
  end

  test "authorizes for root when requested" do
    sign_in users(:one)
    accounts = []
    authorizer = lambda do |_server, _profile, account:, **|
      accounts << account
      result(:added)
    end

    stub_method(ProfileAuthorization, :call, authorizer) do
      post server_authorizations_path(servers(:web)), params: { profile_id: profiles(:alice).id, account: "root" }, as: :turbo_stream
    end

    assert_equal [ "root" ], accounts.map(&:name)
    assert_turbo_stream action: :replace, target: dom_id(servers(:web), :authorized_keys) do
      assert_select "turbo-frame[src=?]", server_authorized_keys_path(servers(:web), account: "root")
    end
    assert_turbo_stream action: :update, target: "flash" do
      assert_select "div", text: "Le profil « Alice » est maintenant autorisé sur « Web » pour root."
    end
  end

  test "rejects an invalid account name" do
    sign_in users(:one)
    post server_authorizations_path(servers(:web)), params: { profile_id: profiles(:alice).id, account: "../root" }
    assert_response :bad_request
  end
end
