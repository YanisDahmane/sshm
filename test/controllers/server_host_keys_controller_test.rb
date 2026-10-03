require "test_helper"

class ServerHostKeysControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include StubHelpers

  setup do
    @server = servers(:web)
    @old = SshKeyGenerator.generate
    @new = SshKeyGenerator.generate
    FileUtils.mkdir_p(KnownHosts.file.dirname)
    KnownHosts.file.write("#{entry(@old)}\n10.9.9.9 #{@other = SshKeyGenerator.generate.public_key.split.first(2).join(" ")}\n")
  end

  teardown { KnownHosts.file.delete if KnownHosts.file.exist? }

  # Mimics net-ssh pinning whatever key the server presents (accept_new).
  def presenting(key)
    ->(server, **) { KnownHosts.file.write(KnownHosts.file.read + "#{entry(key)}\n"); SshCheck::Result.new(success: true, message: "ok", details: "ok") }
  end

  def entry(key)
    name = @server.port == 22 ? @server.host : "[#{@server.host}]:#{@server.port}"
    "#{name} #{key.public_key.split.first(2).join(" ")}"
  end

  test "requires authentication" do
    post server_host_key_path(@server), params: { fingerprint: @new.fingerprint }
    assert_redirected_to new_user_session_path
  end

  test "replaces the pinned key when the server presents the expected one" do
    sign_in users(:one)

    stub_method(SshCheck, :call, presenting(@new)) do
      post server_host_key_path(@server), params: { fingerprint: @new.fingerprint }
    end

    assert_redirected_to server_path(@server)
    assert_match "Nouvelle empreinte acceptée", flash[:notice]
    assert_equal [ @new.fingerprint ], KnownHosts.fingerprints(@server.host, @server.port)
    assert_includes KnownHosts.file.read, "10.9.9.9 #{@other}", "other hosts are kept"

    activity = Activity.last
    assert_equal "host_key_changed", activity.kind
    assert_equal users(:one), activity.user
    assert_equal @server, activity.server
    assert_equal({ "new_fingerprint" => @new.fingerprint, "previous_fingerprints" => [ @old.fingerprint ] },
                 activity.data.slice("new_fingerprint", "previous_fingerprints"))
  end

  test "pins nothing when the server presents yet another key" do
    sign_in users(:one)
    third = SshKeyGenerator.generate

    assert_no_difference "Activity.count" do
      stub_method(SshCheck, :call, presenting(third)) do
        post server_host_key_path(@server), params: { fingerprint: @new.fingerprint }
      end
    end

    assert_redirected_to server_path(@server)
    assert_match "ne présente plus l'empreinte affichée", flash[:alert]
    assert_equal [], KnownHosts.fingerprints(@server.host, @server.port)
  end

  test "is forbidden to non admins and changes nothing" do
    sign_in users(:operator)

    post server_host_key_path(@server), params: { fingerprint: @new.fingerprint }

    assert_response :forbidden
    assert_equal [ @old.fingerprint ], KnownHosts.fingerprints(@server.host, @server.port)
  end

  test "requires the fingerprint" do
    sign_in users(:one)
    post server_host_key_path(@server)
    assert_response :bad_request
  end
end
