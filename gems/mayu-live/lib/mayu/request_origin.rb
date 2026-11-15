# frozen_string_literal: true

require "uri"
require "ipaddr"

module Mayu
  # Shared by configuration validation and the browser request boundary.
  module RequestOrigin
    class Rejected < StandardError
    end

    def self.parse(value, referer: false)
      raise ArgumentError, "Expected an HTTP(S) origin" unless value.is_a?(String)

      uri = URI.parse(value)
      valid = %w[http https].include?(uri.scheme) && uri.hostname &&
        !uri.hostname.empty? && !uri.hostname.include?("%") &&
        uri.port&.between?(1, 65_535) && !uri.userinfo &&
        (referer || (["", "/"].include?(uri.path) && !uri.query && !uri.fragment))
      unless valid
        raise ArgumentError, "Expected an HTTP(S) origin"
      end

      [uri.scheme, uri.hostname.downcase, uri.port]
    rescue URI::InvalidURIError
      raise ArgumentError, "Expected an HTTP(S) origin"
    end

    def self.normalize(value)
      scheme, host, port = parse(value)
      host = "[#{host}]" if host.include?(":")
      suffix = if port == ((scheme == "https") ? 443 : 80)
        ""
      else
        ":#{port}"
      end
      "#{scheme}://#{host}#{suffix}".freeze
    end

    def self.resolve(request, public_origin: nil, trusted_proxies: [])
      return normalize(public_origin) if public_origin

      peer_ip = request.peer&.ip_address unless trusted_proxies.empty?
      trusted = peer_ip && trusted_proxies.any? { it.include?(IPAddr.new(peer_ip).native) }
      if trusted
        scheme = header(request, "x-forwarded-proto")
        host = header(request, "x-forwarded-host")
        unless %w[http https].include?(scheme) && host && !host.match?(/[\s,\/@?#]/)
          raise ArgumentError, "Expected one forwarded scheme and host from the trusted proxy"
        end
        normalize("#{scheme}://#{host}")
      else
        normalize("#{request.scheme}://#{request.authority}")
      end
    end

    def self.header(request, name)
      # Read raw fields: list parsing can discard empty values and hide a
      # duplicate or a trailing comma in an application-defined singular field.
      fields = request.headers.each.select { |key, _| key.casecmp?(name) }
      return nil if fields.empty?
      raise ArgumentError, "Expected one #{name} header" unless fields.length == 1

      value = fields.first.last
      raise ArgumentError, "Expected a string #{name} header" unless value.is_a?(String)

      value
    end

    def self.allowed?(request, expected_origin:)
      site = header(request, "sec-fetch-site")
      return false if site && !%w[same-origin none].include?(site)

      expected = parse(expected_origin)
      if (origin = header(request, "origin"))
        parse(origin) == expected
      elsif site == "same-origin"
        true
      elsif (referer = header(request, "referer"))
        parse(referer, referer: true) == expected
      else
        false
      end
    rescue ArgumentError
      false
    end
  end
end
