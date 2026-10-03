# One public key line of an authorized_keys file (see sshd(8), "AUTHORIZED_KEYS FILE FORMAT"):
#
#   [options] keytype base64-key [comment]
#
# The comment is what we call the key's name: a key without one is "unknown".
class AuthorizedKey
  KEY_TYPES = %w[
    ssh-ed25519 ssh-rsa ssh-dss
    ecdsa-sha2-nistp256 ecdsa-sha2-nistp384 ecdsa-sha2-nistp521
    sk-ssh-ed25519@openssh.com sk-ecdsa-sha2-nistp256@openssh.com
  ].freeze

  LINE_REGEXP = /
    \A(?:(?<options>.*?)\s+)?                                     # optional options, e.g. from="10.0.0.1",no-pty
    (?<type>#{KEY_TYPES.map { |type| Regexp.escape(type) }.join("|")})
    \s+(?<key>[A-Za-z0-9+\/]+={0,2})
    (?:\s+(?<comment>.*))?\z
  /x

  attr_reader :type, :key, :comment, :options, :line_number

  # Parses the content of an authorized_keys file, skipping blank lines,
  # comments and lines that are not valid keys.
  def self.parse(content)
    content.to_s.each_line.with_index(1).filter_map do |line, line_number|
      line = line.strip
      next if line.empty? || line.start_with?("#")

      match = LINE_REGEXP.match(line)
      next unless match && valid_blob?(match[:type], match[:key])

      new(type: match[:type], key: match[:key], comment: match[:comment], options: match[:options], line_number: line_number)
    end
  end

  # The base64 blob must decode and start with its own key type.
  def self.valid_blob?(type, key)
    blob = Base64.strict_decode64(key)
    Net::SSH::Buffer.new(blob).read_string == type
  rescue ArgumentError, Net::SSH::Exception
    false
  end
  private_class_method :valid_blob?

  def initialize(type:, key:, comment: nil, options: nil, line_number: nil)
    @type = type
    @key = key
    @comment = comment&.strip.presence
    @options = options&.strip.presence
    @line_number = line_number
  end

  def name = comment

  # The authorized_keys line for this key.
  def to_line = [ options, type, key, comment ].compact.join(" ")

  def named? = comment.present?

  def fingerprint
    SshKeyGenerator.fingerprint(Base64.strict_decode64(key))
  end

  # True when this is the given SshKey's public key (compared on the key
  # itself, not the comment, which anyone can change).
  def matches?(ssh_key)
    return false unless ssh_key

    other_type, other_key = ssh_key.public_key.split(" ")
    type == other_type && key == other_key
  end
end
