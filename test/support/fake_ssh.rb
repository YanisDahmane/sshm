# In-memory stand-in for Net::SSH, used through SshConnection's `transport:`.
class FakeSsh
  Response = Struct.new(:stdout, :stderr, :exit_status)

  attr_reader :started_with, :commands

  # `handler` computes a Response from the command when it is not in `responses`.
  def initialize(responses: {}, handler: nil, error: nil)
    @responses = responses
    @handler = handler
    @error = error
    @commands = []
  end

  # Net::SSH.start(host, user, **options) { |session| ... }
  def start(host, user, **options)
    @started_with = { host: host, user: user, **options }
    raise @error if @error

    yield Session.new(self)
  end

  def response_for(command)
    @commands << command
    @responses.fetch(command) { @handler&.call(command) || Response.new("", "#{command}: command not found\n", 127) }
  end

  class Session
    def initialize(fake)
      @fake = fake
    end

    # Net::SSH::Connection::Session#exec!(command, status:) { |channel, stream, data| ... }
    def exec!(command, status:)
      response = @fake.response_for(command)
      yield nil, :stdout, response.stdout if response.stdout.present?
      yield nil, :stderr, response.stderr if response.stderr.present?
      status[:exit_code] = response.exit_status
    end
  end
end
