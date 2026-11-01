require "strscan"

# Reads a big JSON object ({ "key": value, … }, like the 60+ MB of the
# Debian Security Tracker) member by member from an IO, in chunks: only one
# member is parsed at a time, never the whole document (AUDIT.md S23).
#
#   Vulnerabilities::JsonObjectStream.each(io) { |key, value| … }
class Vulnerabilities::JsonObjectStream
  class Error < StandardError; end

  CHUNK = 1 << 20
  STRING_REST = /(?:[^"\\]|\\.)*"/m
  WHITESPACE = /[\s,]*/

  def self.each(io, chunk: CHUNK, &block) = new(io, chunk).each(&block)

  def initialize(io, chunk)
    @io = io
    @chunk = chunk
    # Bytes: a chunk may end in the middle of a UTF-8 character. The
    # delimiters looked for are ASCII, never part of a multi-byte character.
    @buffer = String.new(encoding: Encoding::BINARY)
    @pos = 0
  end

  def each
    read_more until (start = @buffer.index("{")) || @io.eof?
    raise Error, "Ce fichier n'est pas un objet JSON" unless start && @buffer.byteslice(0, start).strip.empty?

    @pos = start + 1
    loop do
      member = next_member
      if member == :more
        raise Error, "JSON tronqué" unless read_more
      elsif member == :end
        return
      else
        yield member.first, JSON.parse(member.last.force_encoding(Encoding::UTF_8))
      end
    end
  end

  private

  # Next "key": value from @pos: [key, value_json], :end, or :more when the
  # buffer ends before the member does.
  def next_member
    scanner = StringScanner.new(@buffer)
    scanner.pos = @pos
    scanner.skip(WHITESPACE)
    return :more if scanner.eos?
    return finish(scanner) if scanner.skip(/\}/)
    raise Error, "JSON invalide près de « #{scanner.peek(20)} »" unless scanner.skip(/"/)

    key_start = scanner.pos - 1
    return :more unless scanner.skip(STRING_REST)

    key = JSON.parse(@buffer.byteslice(key_start, scanner.pos - key_start).force_encoding(Encoding::UTF_8))
    scanner.skip(/\s*/)
    return :more if scanner.eos?
    raise Error, "JSON invalide après « #{key} »" unless scanner.skip(/:/)

    scanner.skip(/\s*/)
    value_start = scanner.pos
    return :more unless skip_value(scanner)

    @pos = scanner.pos
    [ key, @buffer.byteslice(value_start, scanner.pos - value_start) ]
  end

  def finish(scanner)
    @pos = scanner.pos
    :end
  end

  # Moves past one value (balanced object / array, string, scalar); false if
  # the buffer ends first.
  def skip_value(scanner)
    case scanner.peek(1)
    when "{", "["
      depth = 0
      loop do
        token = scanner.scan_until(/[{}\[\]"]/) or return false
        case token[-1]
        when "{", "[" then depth += 1
        when "}", "]"
          depth -= 1
          return true if depth.zero?
        else
          scanner.skip(STRING_REST) or return false
        end
      end
    when '"'
      scanner.getch
      scanner.skip(STRING_REST) ? true : false
    when ""
      false
    else
      scanner.skip(/[^,}\]\s]+/) && !scanner.eos?
    end
  end

  # Appends the next chunk, dropping what was already read. False at the end.
  def read_more
    chunk = @io.read(@chunk)
    return false if chunk.nil?

    @buffer = @buffer.byteslice(@pos..) << chunk.b
    @pos = 0
    true
  end
end
