require "test_helper"

class AuthorizedKeyRemovalTest < ActiveSupport::TestCase
  include LocalShellHelpers

  setup do
    @known_hosts = Rails.root.join("tmp", "test", "ssh-#{SecureRandom.hex(4)}", "known_hosts")
    setup_temp_home
    authorized_keys_file.dirname.mkpath
    @alice = SshKeyGenerator.generate(comment: "alice").public_key
    @bob = SshKeyGenerator.generate(comment: "bob").public_key
    @alice_blob = @alice.split(" ")[1]
  end

  teardown do
    FileUtils.rm_rf(@known_hosts.dirname)
    teardown_temp_home
  end

  def remove(blob, fake: FakeSsh.new(handler: local_shell))
    AuthorizedKeyRemoval.call(servers(:web), blob, transport: fake, known_hosts_file: @known_hosts)
  end

  test "script removes the key and keeps everything else byte for byte" do
    authorized_keys_file.write("# team keys\n#{@bob}\n#{@alice}\n\n# end\n")

    assert_equal "removed", run_local_script(AuthorizedKeyRemoval.remove_script(@alice_blob))
    assert_equal "# team keys\n#{@bob}\n\n# end\n", authorized_keys_file.read
  end

  test "script removes every line holding the key, with or without options" do
    type = @alice.split(" ")[0]
    authorized_keys_file.write("#{@alice}\nno-pty,from=\"10.0.0.1\" #{type} #{@alice_blob} again\n#{@bob}\n")

    run_local_script(AuthorizedKeyRemoval.remove_script(@alice_blob))

    assert_equal "#{@bob}\n", authorized_keys_file.read
  end

  test "script leaves the file untouched when the key is absent" do
    authorized_keys_file.write(@bob) # no trailing newline

    assert_equal "absent", run_local_script(AuthorizedKeyRemoval.remove_script(@alice_blob))
    assert_equal @bob, authorized_keys_file.read
  end

  test "script does not match the blob inside a comment or another field" do
    authorized_keys_file.write("#{@bob} copy-of-#{@alice_blob}\n")

    assert_equal "absent", run_local_script(AuthorizedKeyRemoval.remove_script(@alice_blob))
  end

  test "script reports absent when there is no authorized_keys file" do
    authorized_keys_file.delete if authorized_keys_file.exist?

    assert_equal "absent", run_local_script(AuthorizedKeyRemoval.remove_script(@alice_blob))
    assert_not authorized_keys_file.exist?
  end

  test "script keeps the file permissions and leaves no temporary file" do
    authorized_keys_file.write("#{@alice}\n#{@bob}\n")
    authorized_keys_file.chmod(0o600)

    run_local_script(AuthorizedKeyRemoval.remove_script(@alice_blob))

    assert_equal "600", format("%o", authorized_keys_file.stat.mode & 0o777)
    assert_equal [ "authorized_keys" ], authorized_keys_file.dirname.children.map { |path| path.basename.to_s }
  end

  test "removes the key over SSH" do
    authorized_keys_file.write("#{@alice}\n#{@bob}\n")

    result = remove(@alice_blob)

    assert result.removed?
    assert_equal "#{@bob}\n", authorized_keys_file.read
  end

  test "reports a key that is already gone" do
    authorized_keys_file.write("#{@bob}\n")

    result = remove(@alice_blob)

    assert result.success?
    assert result.absent?
  end

  test "refuses to remove the SSHM key without connecting" do
    fake = FakeSsh.new(handler: local_shell)
    master_blob = ssh_keys(:main).public_key.split(" ")[1]
    authorized_keys_file.write("#{ssh_keys(:main).public_key}\n")

    result = remove(master_blob, fake: fake)

    assert_not result.success?
    assert_equal "Suppression interdite", result.error_title
    assert_nil fake.started_with
    assert_includes authorized_keys_file.read, master_blob
  end

  test "refuses a malformed key without connecting" do
    fake = FakeSsh.new(handler: local_shell)

    [ "", nil, "abc'; rm -rf ~; '", "a b" ].each do |blob|
      result = remove(blob, fake: fake)
      assert_equal "Clé invalide", result.error_title, "#{blob.inspect} should be rejected"
    end
    assert_nil fake.started_with
  end

  test "returns the SSH error when the connection fails" do
    result = remove(@alice_blob, fake: FakeSsh.new(error: Errno::ECONNREFUSED.new))

    assert_not result.success?
    assert_equal "Connexion impossible", result.error_title
  end

  test "removes from root's file through sudo" do
    fake = FakeSsh.new(handler: ->(_command) { FakeSsh::Response.new("removed\n", "", 0) })

    result = AuthorizedKeyRemoval.call(servers(:web), @alice_blob, account: AuthorizedKeysAccount.for(servers(:web), "root"),
                                       transport: fake, known_hosts_file: @known_hosts)

    assert result.removed?
    *prefix, script = Shellwords.split(fake.commands.sole)
    assert_equal %w[sudo -n sh -c], prefix
    assert_includes script.lines, "home=~root\n"
  end

  test "refuses to remove the SSHM key from root's file too" do
    fake = FakeSsh.new
    master_blob = ssh_keys(:main).public_key.split(" ")[1]

    result = AuthorizedKeyRemoval.call(servers(:web), master_blob, account: AuthorizedKeysAccount.for(servers(:web), "root"),
                                       transport: fake, known_hosts_file: @known_hosts)

    assert_equal "Suppression interdite", result.error_title
    assert_nil fake.started_with
  end

  test "the script honours the home parameter" do
    custom = @home.join("other", ".ssh")
    custom.mkpath
    custom.join("authorized_keys").write("#{@alice}\n#{@bob}\n")
    authorized_keys_file.write("#{@alice}\n")

    run_local_script(AuthorizedKeyRemoval.remove_script(@alice_blob, home: Shellwords.escape(custom.dirname.to_s)))

    assert_equal "#{@bob}\n", custom.join("authorized_keys").read
    assert_equal "#{@alice}\n", authorized_keys_file.read
  end

  test "the script stops on an unknown user" do
    script = AuthorizedKeyRemoval.remove_script(@alice_blob, home: "~nosuchuser#{SecureRandom.hex(2)}")

    _output, error, status = Open3.capture3({ "HOME" => @home.to_s }, "sh", "-c", script)

    assert_not status.success?
    assert_equal "unknown user", error.strip
  end
end
