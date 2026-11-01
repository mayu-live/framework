# frozen_string_literal: true

require "minitest/autorun"
require "protocol/http/request"
require "async/http/protocol"
require_relative "app"
require "mayu/test"

class Mayu::Server::SessionHooksTest < Minitest::Test
  def setup
    @environment = Mayu::Environment.allocate
    @environment.instance_variable_set(:@request_wrappers, [])
    @environment.instance_variable_set(:@metrics, Mayu::Test::FakeMetrics.new)
    server_config = Object.new
    def server_config.render_exceptions? = false
    def server_config.public_origin = nil
    def server_config.trusted_proxies = []
    @environment.instance_variable_set(:@config, Struct.new(:server).new(server_config))
    @sessions = Mayu::Session::Store.new(metrics: @environment.metrics)
    @app = Mayu::Server::App.allocate
    @app.instance_variable_set(:@environment, @environment)
    @app.instance_variable_set(:@sessions, @sessions)
    @app.instance_variable_set(:@cookies, Mayu::Server::Cookies.new)
  end

  def request(method = "GET", path = "/", headers = {}, body = nil)
    Protocol::HTTP::Request[method, path, {"sec-fetch-site" => "same-origin", **headers}, body].tap do |req|
      req.scheme = "https"
      req.authority = "app.example"
      req.version = "HTTP/2"
      def req.deconstruct_keys(keys) = keys.to_h { [it, public_send(it)] }
    end
  end

  def test_wrappers_are_ordered_and_can_short_circuit_public_requests
    calls = []
    2.times do |index|
      @environment.around_request do |req, following|
        calls << index
        following.call(req).tap { calls << -index - 1 }
      end
    end
    @environment.around_request { |_req, _following| Protocol::HTTP::Response[202, {}, ["public"]] }
    result = @app.call(request)
    assert_equal 202, result.status
    assert_equal [0, 1, -2, -1], calls
  end

  def test_wrapper_continuation_can_only_run_once
    @environment.around_request do |req, following|
      following.call(req)
      following.call(req)
    end
    @environment.around_request { |*| Protocol::HTTP::Response[200] }
    assert_raises(RuntimeError) { @app.call(request) }
  end

  def test_preparation_redirect_creates_no_session
    @environment.prepare_session { |_| Mayu::Session::Preparation.redirect("/login") }
    result = @app.call(request)
    assert_equal 303, result.status
    assert_empty @sessions.instance_variable_get(:@sessions)
  end

  def test_hash_preparation_and_simple_validity_policy
    @environment.prepare_session { |_| {account_id: 42} }
    seen = nil
    @environment.authorize_session(&->(info) {
      seen = info.context
      true
    })
    result = @app.call(request)
    assert_equal 404, result.status
    assert_equal({account_id: 42}, seen)
    assert seen.frozen?
  end

  def test_origin_rejection_does_not_invalidate_an_existing_session
    session = new_session
    @sessions.store(session)
    @environment.authorize_session { |*| flunk "must not authorize" }
    result = @app.call(request("GET", "/.mayu/session/#{session.id}", {"origin" => "https://attacker.example"}))
    assert_equal "REQUEST_ORIGIN_REJECTED", JSON.parse(result.read).fetch("code")
    refute session.invalidated?
    assert_same session, @sessions.authenticate!(session.id, session.token)
  end

  def test_external_get_navigation_can_prepare_a_new_page
    @environment.prepare_session { |_| {account_id: 42} }
    result = @app.call(request("GET", "/", {"sec-fetch-site" => "cross-site", "origin" => "https://other.example"}))
    assert_equal 404, result.status
    assert_includes result.headers["set-cookie"].to_s, "SameSite=Strict"
  end

  def test_event_transport_is_checked_before_reading_messages
    session = new_session
    @sessions.store(session)
    req = request("PATCH", "/.mayu/session/#{session.id}", {"cookie" => "mayu-token=#{session.token}"})
    def req.read = raise("must not read events")
    @environment.authorize_session(&->(info, phase:, request:) {
      assert_equal session.id, info.id
      assert_equal :events, phase
      assert_same req, request
      false
    })
    result = @app.call(req)
    assert_equal "APPLICATION_SESSION_REJECTED", JSON.parse(result.read).fetch("code")
    assert session.invalidated?
  end

  def test_callback_validity_policy_receives_event_metadata
    session = new_session
    callback = Mayu::Session::Events::CallbackEvent["listener", {value: "final"}, 1, settle_id: "s1"]
    @environment.authorize_session do |info, request:, phase:, event:|
      assert_equal session.id, info.id
      assert_nil request
      assert_equal :event, phase
      assert_same callback, event
      true
    end
    assert session.authorize_work(callback)
    @environment.authorize_session { |_| false }
    refute session.authorize_work(callback)
    assert session.invalidated?
  end

  def test_prepared_context_and_cookies_are_available_without_changing_request
    @environment.prepare_session do |_req|
      Mayu::Session::Preparation.new(context: {account_id: 42}, headers: [
        ["set-cookie", "application=new; Path=/"],
        ["set-cookie", "csrf=new; Path=/"]
      ])
    end
    seen = nil
    @environment.authorize_session do |info, request:, phase:, **|
      seen = [info, request.headers.to_h, phase]
      true
    end
    req = request("GET", "/", {"accept" => "text/html", "cookie" => "old=value"})
    result = @app.call(req)
    assert_equal 404, result.status
    assert_equal({account_id: 42}, seen[0].context)
    assert_equal :start, seen[2]
    assert_equal ["old=value"], seen[1]["cookie"]
    cookies = result.headers.to_h.fetch("set-cookie")
    assert_equal 3, cookies.length
    assert_match(/^mayu-token=/, cookies.first)
    assert_equal ["application=new; Path=/", "csrf=new; Path=/"], cookies.last(2)
    refute_includes result.read, "account_id"
  end

  def test_start_denial_happens_before_component_or_route_resolution
    @environment.authorize_session { |*| false }
    @environment.define_singleton_method(:module_provider) { raise "must not resolve" }
    # Enter the selected page directly: public routing has already selected it.
    assert_raises(Mayu::Session::Rejected) { @app.send(:handle_session_start, request) }
    assert_empty @sessions.instance_variable_get(:@sessions)
  end

  def test_reconnect_denial_is_terminal_and_persists_in_the_store
    session = new_session
    @sessions.store(session)
    @environment.authorize_session { |*| raise Mayu::Session::Rejected.new(location: "/login") }
    req = request("GET", "/.mayu/session/#{session.id}", {"cookie" => "mayu-token=#{session.token}"})
    2.times do
      result = @app.call(req)
      assert_equal 403, result.status
      assert_equal({"code" => "APPLICATION_SESSION_REJECTED", "location" => "/login"}, JSON.parse(result.read))
    end
    assert session.invalidated?
    assert_equal session, @sessions.authenticate!(session.id, session.token)
    assert_raises(Mayu::Session::Rejected) { session.transfer! }
  end

  def test_native_token_authentication_precedes_application_authorization
    session = new_session
    @sessions.store(session)
    called = false
    @environment.authorize_session { |*| called = true }
    result = @app.call(request("GET", "/.mayu/session/#{session.id}", {"cookie" => "mayu-token=#{Mayu::Session::Token.generate}"}))
    assert_equal "INVALID_TOKEN", JSON.parse(result.read).fetch("code")
    refute called
  end

  def test_explicit_invalidation_is_idempotent_and_rejects_events
    session = new_session
    @sessions.store(session)
    assert @app.invalidate_session(session.id, location: "/login")
    refute @app.invalidate_session(session.id, location: "/other")
    assert_raises(Mayu::Session::Rejected) { session.receive_message(["Ping", 1]) }
    batch = session.dequeue_batch
    assert batch.terminal?
    assert_equal [Mayu::Runtime::Commands::SessionInvalidated["/login"]], batch.commands
    refute @app.invalidate_session("missing")
  end

  def test_unexpected_transport_authorizer_failure_is_an_internal_error
    session = new_session
    @sessions.store(session)
    @environment.authorize_session { |*| raise "authorization service unavailable" }
    result = @app.call(request("GET", "/.mayu/session/#{session.id}", {"cookie" => "mayu-token=#{session.token}"}))
    assert_equal 500, result.status
    assert_equal "INTERNAL_SERVER_ERROR", JSON.parse(result.read).fetch("code")
    refute session.invalidated?
  end

  def test_transfer_is_authorized_before_restoration
    session = new_session
    marshaller = Mayu::EncryptedMarshal.new("test secret")
    @environment.instance_variable_set(:@marshaller, marshaller)
    transfer = Mayu::Session::TransferState.from_session(session)
    @environment.authorize_session do |info, phase:, **|
      assert_equal :transfer, phase
      assert_equal session.id, info.id
      assert info.context.frozen?
      assert info.path.frozen?
      false
    end
    # If restoration occurs, this payload cannot be loaded.
    transfer = transfer.with(state: "not a serialized component tree")
    result = @app.call(request("POST", "/.mayu/session/#{session.id}", {"cookie" => "mayu-token=#{session.token}"}, [transfer.encrypt(marshaller)]))
    assert_equal 403, result.status
    assert_equal "APPLICATION_SESSION_REJECTED", JSON.parse(result.read).fetch("code")
  end

  def test_invalidation_during_transfer_authorization_prevents_restoration
    session = new_session
    @sessions.store(session)
    marshaller = Mayu::EncryptedMarshal.new("test secret")
    @environment.instance_variable_set(:@marshaller, marshaller)
    transfer = Mayu::Session::TransferState.from_session(session).with(state: "must not deserialize")
    @environment.authorize_session do |*|
      @app.invalidate_session(session.id)
      true
    end
    result = @app.call(request("POST", "/.mayu/session/#{session.id}", {"cookie" => "mayu-token=#{session.token}"}, [transfer.encrypt(marshaller)]))
    assert_equal 403, result.status
    assert_equal "APPLICATION_SESSION_REJECTED", JSON.parse(result.read).fetch("code")
    assert_same session, @sessions.authenticate!(session.id, session.token)
  end

  def test_navigation_denial_prevents_route_resolution
    session = new_session
    @environment.authorize_session { |_info, event:, **| event.path != "/private" }
    @environment.define_singleton_method(:module_provider) { raise "must not resolve" }
    session.send(:handle_event, Mayu::Session::Events::NavigateEvent["n1", "/private", 1])
    assert session.invalidated?
    assert_equal "/", session.info.path
  end

  def test_navigation_authorizer_exception_fails_navigation_without_invalidation
    session = new_session
    @environment.authorize_session { |*| raise "service unavailable" }
    session.send(:handle_event, Mayu::Session::Events::NavigateEvent["n1", "/private", 1])
    refute session.invalidated?
    commands = [session.dequeue_batch, session.dequeue_batch].flat_map(&:commands)
    assert_includes commands, Mayu::Runtime::Commands::NavigationFailed["n1"]
    assert_equal "/", session.info.path
  end

  def test_transfer_with_missing_metadata_uses_restore_failed_recovery
    session = new_session
    marshaller = Mayu::EncryptedMarshal.new("test secret")
    @environment.instance_variable_set(:@marshaller, marshaller)
    transfer = Mayu::Session::TransferState.from_session(session).with(info: nil)
    result = @app.call(request("POST", "/.mayu/session/#{session.id}", {"cookie" => "mayu-token=#{session.token}"}, [transfer.encrypt(marshaller)]))
    assert_equal 422, result.status
    assert_equal "SESSION_RESTORE_FAILED", JSON.parse(result.read).fetch("code")
  end

  def test_pages_on_different_domains_capture_separate_destination_origins
    origins = []
    @environment.prepare_session { |_| {origin: "https://context.example"} }
    @environment.authorize_session do |info|
      origins << info.origin
      assert info.origin.frozen?
      assert_equal "https://context.example", info.context[:origin]
      true
    end
    %w[foo.local bar.local].each do |host|
      req = request("GET", "/", {"accept" => "text/html", "origin" => "https://elsewhere.example", "sec-fetch-site" => "cross-site"})
      req.authority = host
      response = @app.call(req)
      assert_equal 404, response.status
      id = response.headers["x-mayu-session-id"].to_s
      token = response.headers["set-cookie"].to_s[/mayu-token=(\w+)/, 1]
      assert_equal "https://#{host}", @sessions.authenticate!(id, token).origin
    end
    assert_equal %w[https://foo.local https://bar.local], origins
  end

  def test_each_domain_can_resume_its_own_session
    @app.define_singleton_method(:run_session_stream) { |_, _| Protocol::HTTP::Response[200] }
    %w[foo.local bar.local].each do |host|
      session = new_session(origin: "https://#{host}")
      @sessions.store(session)
      req = request("GET", "/.mayu/session/#{session.id}", {"origin" => "https://#{host}", "cookie" => "mayu-token=#{session.token}"})
      req.authority = host
      assert_equal 200, @app.call(req).status
    end
  end

  def test_bound_origin_rejects_other_domains_schemes_and_ports_with_valid_tokens
    session = new_session(origin: "https://foo.local")
    @sessions.store(session)
    @environment.authorize_session { |_| flunk "must not run application authorization" }
    %w[GET PATCH].each do |method|
      [["https", "bar.local"], ["http", "foo.local"], ["https", "foo.local:8443"]].each do |scheme, host|
        req = request(method, "/.mayu/session/#{session.id}", {"origin" => "#{scheme}://#{host}", "cookie" => "mayu-token=#{session.token}"})
        req.scheme = scheme
        req.authority = host
        def req.read = raise("must not read events")
        result = @app.call(req)
        assert_equal 403, result.status
        assert_equal "REQUEST_ORIGIN_REJECTED", JSON.parse(result.read).fetch("code")
        refute session.invalidated?
      end
    end
  end

  def test_cross_domain_transfer_is_rejected_before_component_deserialization
    session = new_session(origin: "https://foo.local")
    marshaller = Mayu::EncryptedMarshal.new("test secret")
    @environment.instance_variable_set(:@marshaller, marshaller)
    transfer = Mayu::Session::TransferState.from_session(session).with(state: "must not deserialize")
    @environment.authorize_session { |_| flunk "must not run application authorization" }
    req = request("POST", "/.mayu/session/#{session.id}", {"origin" => "https://bar.local", "cookie" => "mayu-token=#{session.token}"}, [transfer.encrypt(marshaller)])
    req.authority = "bar.local"
    response = @app.call(req)
    assert_equal 403, response.status
    assert_equal "REQUEST_ORIGIN_REJECTED", JSON.parse(response.read).fetch("code")
    refute session.invalidated?
  end

  def test_same_origin_transfer_restores_the_original_binding
    session = new_session(origin: "https://foo.local")
    marshaller = Mayu::EncryptedMarshal.new("test secret")
    @environment.instance_variable_set(:@marshaller, marshaller)
    transfer = Mayu::Session::TransferState.from_session(session)
    @app.define_singleton_method(:run_session_stream) { |_, _| Protocol::HTTP::Response[200] }
    req = request("POST", "/.mayu/session/#{session.id}", {"origin" => "https://foo.local", "cookie" => "mayu-token=#{session.token}"}, [transfer.encrypt(marshaller)])
    req.authority = "foo.local"
    response = @app.call(req)
    assert_equal 200, response.status
    restored = @sessions.authenticate!(session.id, session.token)
    assert_equal "https://foo.local", restored.origin
    assert restored.origin.frozen?
  end

  def test_legacy_and_missing_metadata_transfers_require_a_new_session
    session = new_session
    marshaller = Mayu::EncryptedMarshal.new("test secret")
    @environment.instance_variable_set(:@marshaller, marshaller)
    transfer = Mayu::Session::TransferState.from_session(session)
    [transfer.with(version: 1), transfer.with(info: nil)].each do |invalid|
      response = @app.call(request("POST", "/.mayu/session/#{session.id}", {"cookie" => "mayu-token=#{session.token}"}, [invalid.encrypt(marshaller)]))
      assert_equal 422, response.status
      assert_equal "SESSION_RESTORE_FAILED", JSON.parse(response.read).fetch("code")
    end
  end

  def test_restored_session_must_match_the_authenticated_origin_metadata
    session = new_session(origin: "https://foo.local")
    marshaller = Mayu::EncryptedMarshal.new("test secret")
    @environment.instance_variable_set(:@marshaller, marshaller)
    transfer = Mayu::Session::TransferState.from_session(session)
    transfer = transfer.with(info: transfer.info.with(origin: "https://bar.local"))
    req = request("POST", "/.mayu/session/#{session.id}", {"origin" => "https://bar.local", "cookie" => "mayu-token=#{session.token}"}, [transfer.encrypt(marshaller)])
    req.authority = "bar.local"
    response = @app.call(req)
    assert_equal 422, response.status
    assert_equal "SESSION_RESTORE_FAILED", JSON.parse(response.read).fetch("code")
  end

  private

  def new_session(origin: "https://app.example")
    Mayu::Session.new(environment: @environment, request_info: Mayu::Session::RequestInfo.new(origin:, path: "/", headers: {}, http2: false), context: {account_id: 42})
  end
end
