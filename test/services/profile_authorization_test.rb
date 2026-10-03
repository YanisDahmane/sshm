require "test_helper"

class ProfileAuthorizationTest < ActiveSupport::TestCase
  include LocalShellHelpers

  setup do
    @known_hosts = Rails.root.join("tmp", "test", "ssh-#{SecureRandom.hex(4)}", "known_hosts")
    setup_temp_home
    @profile = profiles(:alice)
    @type, @blob = @profile.public_key.split(" ")
  end

  teardown do
    FileUtils.rm_rf(@known_hosts.dirname)
    teardown_temp_home
  end

  def authorized_keys = authorized_keys_file

  def run_script(line: "#{@type} #{@blob} Alice", blob: @blob)
    run_local_script(ProfileAuthorization.append_script(line, blob))
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

  test "authorizes in root's file through sudo" do
    fake = FakeSsh.new(handler: ->(_command) { FakeSsh::Response.new("added\n", "", 0) })

    result = authorize_as_root(fake)

    assert result.added?
    *prefix, script = Shellwords.split(fake.commands.sole)
    assert_equal %w[sudo -n sh -c], prefix
    assert_includes script.lines, "home=~root\n"
  end

  test "explains when sudo is not available for root" do
    fake = FakeSsh.new(handler: ->(_command) { FakeSsh::Response.new("", "sudo: a password is required\n", 1) })

    result = authorize_as_root(fake)

    assert_equal "Accès root impossible", result.error_title
  end

  test "the script honours the home parameter" do
    custom = @home.join("other")
    custom.mkpath

    run_local_script(ProfileAuthorization.append_script("#{@type} #{@blob} Alice", @blob, home: Shellwords.escape(custom.to_s)))

    assert custom.join(".ssh", "authorized_keys").exist?
    assert_not authorized_keys.exist?
  end

  test "gives the files back to another user when writing as root" do
    fake = FakeSsh.new(handler: ->(_command) { FakeSsh::Response.new("added\n", "", 0) })

    ProfileAuthorization.call(servers(:web), @profile, account: AuthorizedKeysAccount.for(servers(:web), "bob"),
                              transport: fake, known_hosts_file: @known_hosts)

    *prefix, script = Shellwords.split(fake.commands.sole)
    assert_equal %w[sudo -n sh -c], prefix
    assert_includes script.lines, "home=~bob\n"
    assert_includes script, %(chown "bob:$(id -gn bob)" "$home/.ssh" "$file")
  end

  test "does not chown for the login user or root" do
    [ AuthorizedKeysAccount.login(servers(:web)), AuthorizedKeysAccount.for(servers(:web), "root") ].each do |account|
      assert_not_includes ProfileAuthorization.append_script("l", "b", home: account.home, owner: account.owner), "chown"
    end
  end

  test "the script chowns to the owner, which must exist" do
    owner = Etc.getpwuid.name

    run_local_script(ProfileAuthorization.append_script("#{@type} #{@blob} Alice", @blob, owner: owner))

    assert_equal owner, Etc.getpwuid(authorized_keys.stat.uid).name
  end

  test "the script stops on an unknown user without creating anything" do
    script = ProfileAuthorization.append_script("#{@type} #{@blob} Alice", @blob, home: "~nosuchuser#{SecureRandom.hex(2)}")

    _output, error, status = Open3.capture3({ "HOME" => @home.to_s }, "sh", "-c", script, chdir: @home.to_s)

    assert_not status.success?
    assert_equal "unknown user", error.strip
    assert_empty @home.children
  end

  test "an expiring line carries an OpenSSH expiry-time option in UTC" do
    expires_at = Time.zone.parse("2026-10-03 16:42:18 +02:00")

    assert_equal %(expiry-time="20261003144218Z" #{@type} #{@blob} Alice), ProfileAuthorization.line_for(@profile, expires_at)
    assert_equal "#{@type} #{@blob} Alice", ProfileAuthorization.line_for(@profile)
  end

  test "the expiring line is parsed back with its option" do
    run_script(line: ProfileAuthorization.line_for(@profile, 10.minutes.from_now))

    key = AuthorizedKey.parse(authorized_keys.read).sole
    assert_match(/\Aexpiry-time="\d{14}Z"\z/, key.options)
    assert_equal @profile.fingerprint, key.fingerprint
  end

  test "the script replaces an existing line when asked, keeping the other lines" do
    other = SshKeyGenerator.generate(comment: "bob").public_key
    authorized_keys.dirname.mkpath
    authorized_keys.write(%(# team\nexpiry-time="20261003144218Z" #{@type} #{@blob} Alice\n#{other}\n))

    output = run_local_script(ProfileAuthorization.append_script("#{@type} #{@blob} Alice", @blob, replace: true))

    assert_equal "added", output
    assert_equal "# team\n#{other}\n#{@type} #{@blob} Alice\n", authorized_keys.read
    assert_equal [ "authorized_keys" ], authorized_keys.dirname.children.map { |path| path.basename.to_s }
  end

  test "without replace, an existing expiring line is left as it is" do
    authorized_keys.dirname.mkpath
    authorized_keys.write(%(expiry-time="20261003144218Z" #{@type} #{@blob} Alice\n))

    assert_equal "present", run_script
  end

  test "passes expires_at and replace to the script" do
    fake = FakeSsh.new(handler: local_shell)
    authorized_keys.dirname.mkpath
    authorized_keys.write(%(expiry-time="20261003144218Z" #{@type} #{@blob} Alice\n))

    result = ProfileAuthorization.call(servers(:web), @profile, expires_at: Time.utc(2030, 1, 1), replace: true,
                                       transport: fake, known_hosts_file: @known_hosts)

    assert result.added?
    assert_equal %(expiry-time="20300101000000Z" #{@type} #{@blob} Alice\n), authorized_keys.read
  end

  private

  def authorize_as_root(fake)
    ProfileAuthorization.call(servers(:web), @profile, account: AuthorizedKeysAccount.for(servers(:web), "root"),
                              transport: fake, known_hosts_file: @known_hosts)
  end
end
