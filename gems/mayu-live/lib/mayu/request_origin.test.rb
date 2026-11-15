# frozen_string_literal: true

require "minitest/autorun"
require "protocol/http/request"
require_relative "request_origin"
require_relative "configuration"

class Mayu::RequestOriginTest < Minitest::Test
  def allowed?(headers, public_origin: nil, scheme: "https", authority: "app.example")
    request = Protocol::HTTP::Request["POST", "/action", headers]
    request.scheme = scheme
    request.authority = authority
    Mayu::RequestOrigin.allowed?(request, expected_origin: Mayu::RequestOrigin.resolve(request, public_origin:))
  end

  def test_same_origin_evidence_and_referer_fallback
    assert allowed?({"origin" => "https://APP.example:443"})
    assert allowed?({"sec-fetch-site" => "same-origin"})
    assert allowed?({"referer" => "https://app.example/page?tab=1"})
    assert allowed?({"sec-fetch-site" => "none", "referer" => "https://app.example/"})
    assert allowed?({"origin" => "http://localhost:9292"}, scheme: "http", authority: "localhost:9292")
    assert allowed?({"origin" => "https://[::1]:9292"}, authority: "[::1]:9292")
  end

  def test_untrusted_or_missing_evidence_is_rejected
    [
      {},
      {"sec-fetch-site" => "none"},
      {"sec-fetch-site" => "unknown"},
      {"origin" => "https://other.example", "referer" => "https://app.example/"},
      {"origin" => "http://app.example"},
      {"origin" => "https://app.example:444"},
      {"origin" => "https://app.example.attacker.example"},
      {"origin" => "null", "sec-fetch-site" => "same-origin"},
      {"origin" => "", "sec-fetch-site" => "same-origin"},
      {"origin" => "https://app.example/private"},
      {"origin" => "https://app.example, https://app.example"},
      {"origin" => "https://app.example,"},
      {"sec-fetch-site" => "same-origin,"},
      {"referer" => "https://attacker.example/"}
    ].each { |headers| refute allowed?(headers), headers.inspect }

    %w[cross-site same-site].each do |site|
      refute allowed?({"sec-fetch-site" => site, "origin" => "https://app.example"})
    end
  end

  def test_duplicate_security_headers_fail_closed
    %w[origin referer sec-fetch-site].each do |name|
      value = (name == "sec-fetch-site") ? "same-origin" : "https://app.example"
      headers = Protocol::HTTP::Headers[[[name, value], [name, value]]]
      refute allowed?(headers), name
      headers = Protocol::HTTP::Headers[[[name, value], [name, ""]]]
      refute allowed?(headers), "#{name} with an empty duplicate"
    end
  end

  def test_public_origin_is_used_instead_of_internal_proxy_address
    headers = {"origin" => "https://public.example"}
    refute allowed?(headers, scheme: "http", authority: "localhost:3333")
    assert allowed?(headers, public_origin: "https://public.example", scheme: "http", authority: "localhost:3333")
    refute allowed?({"origin" => "http://localhost:3333"}, public_origin: "https://public.example", scheme: "http", authority: "localhost:3333")
  end

  def test_forwarded_headers_do_not_establish_trust
    refute allowed?({
      "origin" => "https://attacker.example",
      "forwarded" => "proto=https;host=attacker.example",
      "x-forwarded-host" => "attacker.example",
      "x-forwarded-proto" => "https"
    })
  end

  def test_public_origin_configuration
    config = Mayu::Configuration::ServerConfig
    assert_nil config.parse({}).public_origin
    assert_equal "https://app.example", config.parse({"public_origin" => "https://app.example"}).public_origin
    [false, 123, "", "null", "//app.example", "ftp://app.example", "https://user:pass@app.example",
      "https://app.example/path", "https://app.example?x=1", "https://app.example#x",
      "https://app.example:99999", "https://", "https://app.example,https://other.example"].each do |origin|
      assert_raises(ArgumentError, origin.inspect) { config.parse({"public_origin" => origin}) }
    end
  end

  def resolve(headers = {}, peer_ip: nil, trusted_proxies: [], public_origin: nil)
    request = Protocol::HTTP::Request["GET", "/", headers]
    request.scheme = "http"
    request.authority = "internal.example:3333"
    peer = Struct.new(:ip_address).new(peer_ip) if peer_ip
    request.define_singleton_method(:peer) { peer }
    Mayu::RequestOrigin.resolve(request, public_origin:, trusted_proxies: trusted_proxies.map { IPAddr.new(it).native })
  end

  def test_origin_normalization
    assert_equal "https://foo.local", Mayu::RequestOrigin.normalize("https://FOO.local:443/")
    assert_equal "http://foo.local", Mayu::RequestOrigin.normalize("http://foo.local:80")
    assert_equal "https://foo.local:8443", Mayu::RequestOrigin.normalize("https://foo.local:8443")
    assert_equal "https://[::1]:8443", Mayu::RequestOrigin.normalize("https://[::1]:8443/")
    assert Mayu::RequestOrigin.normalize("https://foo.local").frozen?
  end

  def test_trusted_proxy_resolves_each_public_origin
    ["127.0.0.1", "::1", "::ffff:127.0.0.1"].each do |peer|
      %w[foo.local bar.local].each do |host|
        assert_equal "https://#{host}", resolve(
          {"x-forwarded-proto" => "https", "x-forwarded-host" => host},
          peer_ip: peer, trusted_proxies: ["127.0.0.0/8", "::1/128"]
        )
      end
    end
    assert_equal "https://foo.local:8443", resolve(
      {"x-forwarded-proto" => "https", "x-forwarded-host" => "foo.local:8443"},
      peer_ip: "10.0.1.2", trusted_proxies: ["10.0.0.0/16"]
    )
  end

  def test_untrusted_and_absent_peers_cannot_supply_forwarded_origins
    headers = {"x-forwarded-proto" => "https", "x-forwarded-host" => "attacker.example"}
    [nil, "192.0.2.1", "::2"].each do |peer|
      assert_equal "http://internal.example:3333", resolve(headers, peer_ip: peer, trusted_proxies: ["127.0.0.1", "::1"])
    end
    assert_equal "http://internal.example:3333", resolve(headers, peer_ip: "127.0.0.1")
  end

  def test_trusted_proxy_headers_must_be_complete_single_values
    [
      {},
      {"x-forwarded-proto" => "https"},
      {"x-forwarded-host" => "foo.local"},
      {"x-forwarded-proto" => "https,http", "x-forwarded-host" => "foo.local"},
      {"x-forwarded-proto" => "https", "x-forwarded-host" => "foo.local,bar.local"},
      {"x-forwarded-proto" => "ftp", "x-forwarded-host" => "foo.local"},
      {"x-forwarded-proto" => "https", "x-forwarded-host" => "user@foo.local"},
      {"x-forwarded-proto" => "https", "x-forwarded-host" => "foo.local/path"},
      {"x-forwarded-proto" => "https", "x-forwarded-host" => ""},
      {"forwarded" => "proto=https;host=foo.local"},
      Protocol::HTTP::Headers[[["x-forwarded-proto", "https"], ["x-forwarded-proto", "https"], ["x-forwarded-host", "foo.local"]]],
      Protocol::HTTP::Headers[[["x-forwarded-proto", "https"], ["x-forwarded-host", "foo.local"], ["x-forwarded-host", ""]]]
    ].each do |headers|
      assert_raises(ArgumentError, headers.inspect) { resolve(headers, peer_ip: "127.0.0.1", trusted_proxies: ["127.0.0.1"]) }
    end
  end

  def test_explicit_origin_precedes_proxy_discovery
    assert_equal "https://fixed.example", resolve({}, peer_ip: "127.0.0.1", trusted_proxies: ["127.0.0.1"], public_origin: "https://FIXED.example:443/")
  end

  def test_trusted_proxy_configuration
    config = Mayu::Configuration::ServerConfig
    assert_empty config.parse({}).trusted_proxies
    networks = config.parse({"trusted_proxies" => ["127.0.0.1", "10.0.0.0/8", "::1/128"]}).trusted_proxies
    assert networks.frozen?
    assert networks.all?(&:frozen?)
    assert networks[1].include?("10.1.2.3")
    [false, "127.0.0.1", [123], ["localhost"], ["bad address"], ["127.0.0.1/99"]].each do |value|
      assert_raises(ArgumentError, value.inspect) { config.parse({"trusted_proxies" => value}) }
    end
  end
end
