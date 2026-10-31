require "test_helper"

class PublicKeyAuthorizationTest < ActiveSupport::TestCase
  include LocalShellHelpers

  setup do
    @known_hosts = Rails.root.join("tmp", "test", "ssh-#{SecureRandom.hex(4)}", "known_hosts")
    setup_temp_home
    @public_key = public_keys(:alice)
    @type, @blob = @public_key.content.split(" ")
  end

  teardown do
    FileUtils.rm_rf(@known_hosts.dirname)
    teardown_temp_home
  end

  def authorized_keys = authorized_keys_file

  def run_script(line: "#{@type} #{@blob} Alice", blob: @blob)
    run_local_script(PublicKeyAuthorization.append_script(line, blob))
  end

  def authorize(fake, public_key: @public_key)
    PublicKeyAuthorization.call(servers(:web), public_key, transport: fake, known_hosts_file: @known_hosts)
  end

  test "script creates ~/.ssh and authorized_keys with private permissions" do
    assert_equal "added", run_script

    assert_equal "#{@type} #{@blob} Alice\n", authorized_keys.read
    assert_equal "700", format("%o", authorized_keys.dirname.stat.mode & 0o777)
    assert_equal "600", format("%o", authorized_keys.stat.mode & 0o777)
  end

  test "script appends after existing keys and leaves them untouched" do
    authorized_keys.dirname.mkpath
    other = Ssh::KeyGenerator.generate(comment: "bob").public_key
    authorized_keys.write("# team\n#{other}\n")

    assert_equal "added", run_script
    assert_equal "# team\n#{other}\n#{@type} #{@blob} Alice\n", authorized_keys.read
  end

  test "script adds a missing trailing newline before appending" do
    authorized_keys.dirname.mkpath
    other = Ssh::KeyGenerator.generate(comment: "bob").public_key
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

  test "authorizes the public_key with its name as comment" do
    fake = FakeSsh.new(handler: local_shell)

    result = authorize(fake)

    assert result.success?
    assert result.added?
    assert_equal "#{@type} #{@blob} Alice\n", authorized_keys.read
    assert fake.commands.sole.start_with?("sh -c ")
  end

  test "reports a public_key that is already authorized" do
    fake = FakeSsh.new(handler: local_shell)
    authorize(fake)

    result = authorize(fake)

    assert result.already_present?
    assert_equal 1, authorized_keys.read.lines.size
  end

  test "the written line is parsed back as the public_key's key" do
    authorize(FakeSsh.new(handler: local_shell))

    key = AuthorizedKey.parse(authorized_keys.read).sole
    assert_equal @public_key.fingerprint, key.fingerprint
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

  test "the script honours the home parameter" do
    custom = @home.join("other")
    custom.mkpath

    run_local_script(PublicKeyAuthorization.append_script("#{@type} #{@blob} Alice", @blob, home: Shellwords.escape(custom.to_s)))

    assert custom.join(".ssh", "authorized_keys").exist?
    assert_not authorized_keys.exist?
  end

  test "an expiring line carries an OpenSSH expiry-time option in UTC" do
    expires_at = Time.zone.parse("2026-10-03 16:42:18 +02:00")

    assert_equal %(expiry-time="20261003144218Z" #{@type} #{@blob} Alice), PublicKeyAuthorization.line_for(@public_key, expires_at)
    assert_equal "#{@type} #{@blob} Alice", PublicKeyAuthorization.line_for(@public_key)
  end

  test "the expiring line is parsed back with its option" do
    run_script(line: PublicKeyAuthorization.line_for(@public_key, 10.minutes.from_now))

    key = AuthorizedKey.parse(authorized_keys.read).sole
    assert_match(/\Aexpiry-time="\d{14}Z"\z/, key.options)
    assert_equal @public_key.fingerprint, key.fingerprint
  end

  test "the script replaces an existing line when asked, keeping the other lines" do
    other = Ssh::KeyGenerator.generate(comment: "bob").public_key
    authorized_keys.dirname.mkpath
    authorized_keys.write(%(# team\nexpiry-time="20261003144218Z" #{@type} #{@blob} Alice\n#{other}\n))

    output = run_local_script(PublicKeyAuthorization.append_script("#{@type} #{@blob} Alice", @blob, replace: true))

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

    result = PublicKeyAuthorization.call(servers(:web), @public_key, expires_at: Time.utc(2030, 1, 1), replace: true,
                                       transport: fake, known_hosts_file: @known_hosts)

    assert result.added?
    assert_equal %(expiry-time="20300101000000Z" #{@type} #{@blob} Alice\n), authorized_keys.read
  end

  private
end
