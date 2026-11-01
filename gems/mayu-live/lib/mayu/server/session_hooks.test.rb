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
    @environment.instance_variable_set(:@config, Struct.new(:server).new(server_config))
    @sessions = Mayu::Session::Store.new(metrics: @environment.metrics)
    @app = Mayu::Server::App.allocate
    @app.instance_variable_set(:@environment, @environment)
    @app.instance_variable_set(:@sessions, @sessions)
    @app.instance_variable_set(:@cookies, Mayu::Server::Cookies.new)
  end

  def request(method = "GET", path = "/", headers = {}, body = nil)
    Protocol::HTTP::Request[method, path, headers, body].tap do |req|
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
    @environment.prepare_session { |_| Protocol::HTTP::Response[303, {"location" => "/login"}] }
    result = @app.call(request)
    assert_equal 303, result.status
    assert_empty @sessions.instance_variable_get(:@sessions)
  end

  def test_prepared_context_and_cookies_are_available_without_changing_request
    @environment.prepare_session do |_req|
      Mayu::Session::Preparation.new(context: {account_id: 42}, headers: [
        ["set-cookie", "application=new; Path=/"],
        ["set-cookie", "csrf=new; Path=/"]
      ])
    end
    seen = nil
    @environment.authorize_session do |info, req, phase|
      seen = [info, req.headers.to_h, phase]
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
    @environment.authorize_session do |info, _req, phase|
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

  def test_navigation_denial_prevents_route_resolution
    session = new_session
    @environment.authorize_event { |_info, event| event.path != "/private" }
    @environment.define_singleton_method(:module_provider) { raise "must not resolve" }
    session.send(:handle_event, Mayu::Session::Events::NavigateEvent["n1", "/private", 1])
    assert session.invalidated?
    assert_equal "/", session.info.path
  end

  def test_navigation_authorizer_exception_fails_navigation_without_invalidation
    session = new_session
    @environment.authorize_event { |*| raise "service unavailable" }
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

  private

  def new_session
    Mayu::Session.new(environment: @environment, request_info: Mayu::Session::RequestInfo.new(path: "/", headers: {}, http2: false), context: {account_id: 42})
  end
end
