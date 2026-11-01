# Debian package versions compared like dpkg does ([epoch:]upstream[-revision];
# "~" sorts before anything, even the end of the string: 1.0~rc1 < 1.0), to
# tell whether an installed version is older than the one that fixes a CVE.
# Ubuntu uses the same scheme.
module Inventory::DebianVersion
  module_function

  # -1, 0 or 1.
  def compare(left, right)
    left_epoch, left_upstream, left_revision = split(left)
    right_epoch, right_upstream, right_revision = split(right)
    (left_epoch <=> right_epoch).nonzero? || compare_part(left_upstream, right_upstream).nonzero? || compare_part(left_revision, right_revision)
  end

  def older?(installed, fixed) = compare(installed, fixed).negative?

  def split(version)
    version = version.to_s.strip
    epoch, rest = version.include?(":") ? version.split(":", 2) : [ "0", version ]
    upstream, _, revision = rest.rpartition("-")
    upstream, revision = rest, "" if upstream.empty?
    [ epoch.to_i, upstream, revision ]
  end

  # dpkg's verrevcmp: alternating non-digit runs (compared character by
  # character with `order`) and digit runs (compared as numbers).
  def compare_part(left, right)
    left_scanner, right_scanner = StringScanner.new(left), StringScanner.new(right)
    until left_scanner.eos? && right_scanner.eos?
      left_text, right_text = left_scanner.scan(/\D*/), right_scanner.scan(/\D*/)
      result = compare_text(left_text, right_text)
      return result unless result.zero?

      result = left_scanner.scan(/\d*/).to_i <=> right_scanner.scan(/\d*/).to_i
      return result unless result.zero?
    end
    0
  end

  def compare_text(left, right)
    [ left.length, right.length ].max.times do |index|
      result = order(left[index]) <=> order(right[index])
      return result unless result.zero?
    end
    0
  end

  def order(char)
    if char.nil? then 0
    elsif char == "~" then -1
    elsif char.match?(/[A-Za-z]/) then char.ord
    else char.ord + 256
    end
  end
end
