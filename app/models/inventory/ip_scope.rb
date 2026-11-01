require "ipaddr"

# Reach of an IP address: public (every interface or a public address),
# private (RFC 1918, CGNAT / Tailscale, IPv6 ULA, link-local) or local (loopback).
module Inventory::IpScope
  PRIVATE_RANGES = %w[10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 100.64.0.0/10 169.254.0.0/16 fc00::/7 fe80::/10].map { |range| IPAddr.new(range) }.freeze

  def self.of(address)
    return "public" if [ "0.0.0.0", "::", "*", "" ].include?(address.to_s)

    ip = IPAddr.new(address.to_s)
    return "local" if ip.loopback?

    PRIVATE_RANGES.any? { |range| range.include?(ip) } ? "private" : "public"
  rescue IPAddr::InvalidAddressError
    "public"
  end

  def self.ip?(text)
    IPAddr.new(text.to_s)
    true
  rescue IPAddr::InvalidAddressError
    false
  end
end
