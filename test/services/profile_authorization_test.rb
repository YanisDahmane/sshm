require "test_helper"
require "open3"

class ProfileAuthorizationTest < ActiveSupport::TestCase
  setup do
    @known_hosts = Rails.root.join("tmp", "test", "ssh-#{SecureRandom.hex(4)}", "known_hosts")
    @home = Pathname(Dir.mktmpdir)
    @profile = profiles(:alice)
    @type, @blob = @profile.public_key.split(" ")
  end

  teardown do
    FileUtils.rm_rf(@known_hosts.dirname)
    FileUtils.rm_rf(@home)
  end

  def authorized_keys = @home.join(".ssh", "authorized_keys")

  # Runs the append script for real with `sh`, in a temporary HOME.
  def run_script(line: "#{@type} #{@blob} Alice", blob: @blob)
    output, status = Open3.capture2({ "HOME" => @home.to_s }, "sh", "-c", ProfileAuthorization.append_script(line, blob))
    assert status.success?, "script failed: #{output}"
    output.strip
  end

  # FakeSsh handler that executes the received `sh -c '…'` command locally.
  def local_shell
    lambda do |command|
      stdout, stderr, status = Open3.capture3({ "HOME" => @home.to_s }, "sh", "-c", command)
      FakeSsh::Response.new(stdout, stderr, status.exitstatus)
    end
  end

  def authorize(fake, profile: @profile)
    ProfileAuthorization.call(servers(:web), profile, transport: fake, known_hosts_file: @known_hosts)
  end

  test "script creates ~/.ssh and authorized_keys with private permissions" do
    assert_equal "added", run_script

    assert_equal "#{@type} #{@blob} Alice\n", authorized_keys.read
    assert_equal "700", format("%o", authorized_keys.dirname.stat.mode & 0o777)
    assert_equal "600", format("%o", authorized_keys.stat.mode & 0o777)
  end

  test "script appends after existing keys and leaves them untouched" do
    authorized_keys.dirname.mkpath
    other = SshKeyGenerator.generate(comment: "bob").public_key
    authorized_keys.write("# team\n#{other}\n")

    assert_equal "added", run_script
    assert_equal "# team\n#{other}\n#{@type} #{@blob} Alice\n", authorized_keys.read
  end

  test "script adds a missing trailing newline before appending" do
    authorized_keys.dirname.mkpath
    other = SshKeyGenerator.generate(comment: "bob").public_key
    authorized_keys.write(other)

    run_script

    assert_equal [ other, "#{@type} #{@blob} Alice" ], authorized_keys.read.lines.map(&:chomp)
  end

  test "script does nothing when the key is already present, whatever its comment" do
    authorized_keys.dirname.mkpath
    authorized_keys.write("no-pty #{@type} #{@blob} renamed\n")

    assert_equal "present", run_script
    assert_equal "no-pty #{@type} #{@blob} renamed\n", authorized_keys.read
  end

  test "script keeps shell metacharacters in the comment literal" do
    run_script(line: %(#{@type} #{@blob} O'Brien $(touch pwned) `id` "x"))

    assert_equal %(#{@type} #{@blob} O'Brien $(touch pwned) `id` "x"\n), authorized_keys.read
    assert_not @home.join("pwned").exist?
  end

  test "authorizes the profile with its name as comment" do
    fake = FakeSsh.new(handler: local_shell)

    result = authorize(fake)

    assert result.success?
    assert result.added?
    assert_equal "#{@type} #{@blob} Alice\n", authorized_keys.read
    assert fake.commands.sole.start_with?("sh -c ")
  end

  test "reports a profile that is already authorized" do
    fake = FakeSsh.new(handler: local_shell)
    authorize(fake)

    result = authorize(fake)

    assert result.already_present?
    assert_equal 1, authorized_keys.read.lines.size
  end

  test "the written line is parsed back as the profile's key" do
    authorize(FakeSsh.new(handler: local_shell))

    key = AuthorizedKey.parse(authorized_keys.read).sole
    assert_equal @profile.fingerprint, key.fingerprint
    assert_equal "Alice", key.name
  end

  test "returns the error when the command fails" do
    fake = FakeSsh.new(handler: ->(_command) { FakeSsh::Response.new("", "touch: cannot touch '/home/deploy/.ssh/authorized_keys': Read-only file system\n", 1) })

    result = authorize(fake)

    assert_not result.success?
    assert_equal "La commande a échoué", result.error_title
    assert_match "Read-only file system", result.error_details
  end

  test "returns the SSH error when the connection fails" do
    result = authorize(FakeSsh.new(error: Errno::ECONNREFUSED.new))

    assert_not result.success?
    assert_equal "Connexion impossible", result.error_title
  end
end
