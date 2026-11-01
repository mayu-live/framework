# frozen_string_literal: true

require "minitest/autorun"
require "protocol/http/request"
require "async/http/protocol"
require_relative "app"
require "mayu/test"

class Mayu::Server::RequestSecurityTest < Minitest::Test
  Match = Data.define(:page, :handler, :params)
  Provider = Data.define(:exports_module) do
    def entry(name) = name
    def exports(_) = exports_module
  end

  def setup
    @calls = []
    calls = @calls
    @handler = Class.new(Mayu::Route) do
      define_method(:POST) { |_|
        calls << :post
        [200, {}, "OK"]
      }
      define_method(:PUT) { |_|
        calls << :put
        [200, {}, "OK"]
      }
    end
    @page = nil
    router = Module.new
    test = self
    router.define_singleton_method(:match) { |_| test.route_match }
    exports = Module.new
    exports.const_set(:Default, router)
    @environment = Mayu::Environment.allocate
    @environment.instance_variable_set(:@module_provider, Provider.new(exports))
    @environment.instance_variable_set(:@request_wrappers, [])
    @environment.instance_variable_set(:@config, Struct.new(:server).new(Mayu::Configuration::ServerConfig.parse({})))
    @app = Mayu::Server::App.allocate
    @app.instance_variable_set(:@environment, @environment)
  end

  def route_match = Match.new(@page, @handler, {})

  def request(method = "POST", path = "/action", headers = {})
    Protocol::HTTP::Request[method, path, headers].tap do |req|
      req.scheme = "https"
      req.authority = "app.example"
      def req.deconstruct_keys(keys) = keys.to_h { [it, public_send(it)] }
      calls = @calls
      req.define_singleton_method(:read) {
        calls << :read
        ""
      }
    end
  end

  def assert_rejected(response)
    assert_equal 403, response.status
    assert_equal "REQUEST_ORIGIN_REJECTED", JSON.parse(response.read).fetch("code")
    assert_equal "no-store", response.headers["cache-control"].to_s
    assert_empty @calls
  end

  def test_rejects_before_handler_or_body_and_wrappers_can_inspect_response
    @environment.around_request do |req, following|
      following.call(req).tap { it.headers.add("x-wrapper", "ran") }
    end
    response = @app.call(request)
    assert_rejected(response)
    assert_equal "ran", response.headers["x-wrapper"].to_s
  end

  def test_same_origin_handler_requests_are_allowed
    response = @app.call(request("POST", "/action", {"origin" => "https://app.example"}))
    assert_equal 200, response.status
    assert_equal [:read, :post], @calls
    assert_nil response.headers["access-control-allow-origin"]
  end

  def test_exemption_only_applies_to_the_declared_handler_method
    @handler.csrf_exempt("POST")
    assert_equal 200, @app.call(request).status
    assert_equal [:read, :post], @calls
    @calls.clear
    assert_rejected @app.call(request("PUT"))
  end

  def test_handler_exemption_does_not_exempt_a_colocated_html_page
    @handler.csrf_exempt("POST")
    @page = Object.new
    @environment.prepare_session { |_| flunk "must not prepare a session" }
    assert_rejected @app.call(request("POST", "/action", {"accept" => "text/html"}))
  end

  def test_all_session_transports_reject_before_authentication_or_body_reads
    @handler.csrf_exempt("POST", "PATCH")
    %w[GET POST PATCH].each do |method|
      assert_rejected @app.call(request(method, "/.mayu/session/abc123"))
    end
  end

  def test_exemptions_require_explicit_uppercase_unsafe_methods
    [[], ["post"], [:POST], ["GET"], ["POST", "UNKNOWN"]].each do |methods|
      assert_raises(ArgumentError) { @handler.csrf_exempt(*methods) }
    end
  end

  def test_incomplete_trusted_proxy_headers_reject_initial_pages_before_preparation
    config = Mayu::Configuration::ServerConfig.parse({"trusted_proxies" => ["127.0.0.1"]})
    @environment.instance_variable_set(:@config, Struct.new(:server).new(config))
    @environment.prepare_session { |_| flunk "must not prepare a session" }
    @page = Object.new
    req = request("GET", "/", {"accept" => "text/html", "x-forwarded-proto" => "https"})
    req.define_singleton_method(:peer) { Struct.new(:ip_address).new("127.0.0.1") }
    assert_rejected @app.call(req)
  end
end
