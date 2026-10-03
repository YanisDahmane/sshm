require "open3"

# Runs the shell scripts sent over SSH for real, locally, in a temporary HOME
# (set up by `setup_temp_home`), so file manipulations can be checked.
module LocalShellHelpers
  def setup_temp_home
    @home = Pathname(Dir.mktmpdir)
  end

  def teardown_temp_home
    FileUtils.rm_rf(@home)
  end

  def authorized_keys_file = @home.join(".ssh", "authorized_keys")

  # Runs `script` with sh in the temporary HOME and returns its stdout.
  def run_local_script(script)
    output, status = Open3.capture2({ "HOME" => @home.to_s }, "sh", "-c", script)
    assert status.success?, "script failed: #{output}"
    output.strip
  end

  # FakeSsh handler that executes the received command locally.
  def local_shell
    lambda do |command|
      stdout, stderr, status = Open3.capture3({ "HOME" => @home.to_s }, "sh", "-c", command)
      FakeSsh::Response.new(stdout, stderr, status.exitstatus)
    end
  end
end
