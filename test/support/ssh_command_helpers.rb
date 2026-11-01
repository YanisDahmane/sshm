# Commands of the fake collectors used in the tests (registered on top of
# config/ssh_commands.yml for the duration of a test).
module SshCommandHelpers
  def with_ssh_commands(definitions)
    Ssh::Commands.extra = definitions
    yield
  ensure
    Ssh::Commands.extra = nil
  end
end
