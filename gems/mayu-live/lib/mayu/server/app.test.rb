#!/usr/bin/env ruby -rbundler/setup
# frozen_string_literal: true

require "minitest/autorun"
require "minitest/mock"
require "async/http/protocol"
require "tmpdir"

require_relative "app"
require_relative "../runtime/commands"

class Mayu::Server::AppTest < Minitest::Test
  class Page < Mayu::Component::Base
  end

  class Handler < Mayu::Route
    def GET(request)
      [
        200,
        {"content-type" => "application/json"},
        request.query.fetch("format")
      ]
    end

    def PUT(request)
      [202, {}, request.params.fetch(:id)]
    end
  end

  class ErroringHandler < Mayu::Route
    def GET(_request) = raise "handler boom"
  end

  Match = Data.define(:page, :handler, :params)
  Environment = Data.define(:module_provider)
  Session = Data.define(:styles)
  Provider =
    Data.define(:exports_module) do
      def entry(name) = name

      def exports(entry)
        raise KeyError unless entry == "virtual:router"

        exports_module
      end
    end

  class RewritingProvider
    attr_reader :rewritten_error

    def initialize(exports_module)
      @exports_module = exports_module
    end

    def entry(name) = name

    def exports(entry)
      raise KeyError unless entry == "virtual:router"

      @exports_module
    end

    def rewrite_exception(error)
      @rewritten_error = error
      error.set_backtrace(["app:/pages/api/+route.rb:3"])
    end
  end
  Request =
    Data.define(:method, :path, :headers, :body) do
      def read = body

      def version = "HTTP/1.1"
    end

  class StreamSession
    DomIdTree = Data.define(:value) { def to_msgpack(packer) = packer.write(value) }

    attr_reader :id, :dom_id_tree

    def startup_commands = []

    def initialize
      @id = "test-session"
      @dom_id_tree = DomIdTree.new([])
      @started = Async::Promise.new
      @stopped = Async::Promise.new
    end

    def running? = false
    def transferring? = false

    def listener_commands
      [Mayu::Runtime::Commands::SetListener["button", "click", "listener"]]
    end

    def start
      @started.resolve(true)
    end

    def wait
      @stopped.wait
    end

    def wait_until_started
      @started.wait
    end

    def stop
      @stopped.resolve(true) unless @stopped.resolved?
    end

    def dequeue_batch
      Async::Promise.new.wait
    end
  end

  def test_html_page_requests_do_not_dispatch_the_handler
    response = dispatch("GET", "/api/42", {"accept" => "text/html"})

    assert_nil(response)
  end

  def test_non_html_requests_dispatch_the_handler_with_route_data
    response =
      dispatch("GET", "/api/42?format=json", {"accept" => "application/json"})

    assert_equal(200, response.status)
    assert_equal("json", response.body.read)
    assert_equal(["accept"], response.headers.to_h.fetch("vary"))
  end

  def test_mutating_requests_dispatch_the_handler_even_when_html_is_accepted
    response = dispatch("PUT", "/api/42", {"accept" => "text/html"})

    assert_equal(202, response.status)
    assert_equal("42", response.body.read)
  end

  def test_html_post_requests_keep_the_live_page_path
    response = dispatch("POST", "/api/42", {"accept" => "text/html"})

    assert_nil(response)
  end

  def test_unsupported_handler_methods_return_405
    response = dispatch("DELETE", "/api/42", {"accept" => "application/json"})

    assert_equal(405, response.status)
    assert_equal(%w[GET PUT], response.headers.to_h.fetch("allow"))
  end

  def test_route_handler_errors_are_rewritten_before_the_server_logs_them
    router = Module.new
    router.define_singleton_method(:match) do |_path|
      Match.new(nil, ErroringHandler, {})
    end
    exports = Module.new
    exports.const_set(:Default, router)
    provider = RewritingProvider.new(exports)
    app = Mayu::Server::App.allocate
    app.instance_variable_set(
      :@environment,
      Environment.new(provider)
    )

    response =
      app.call(
        Request.new("GET", "/api", {"accept" => "application/json"}, "")
      )

    assert_equal(500, response.status)
    refute_nil(provider.rewritten_error)
    assert_equal(
      ["app:/pages/api/+route.rb:3"],
      provider.rewritten_error.backtrace
    )
  end

  ErrorConfig = Data.define(:render_exceptions) do
    def server = self
    def render_exceptions? = render_exceptions
  end
  ErrorEnvironment = Data.define(:module_provider, :config)

  # Only reached when the error page itself fails to render.
  def test_a_render_error_that_escapes_the_session_is_an_html_500
    failure =
      Mayu::Runtime::VNodes::VComponent::UnhandledRenderError.new(
        RuntimeError.new("render boom"),
        nil
      )
    failure.error.set_backtrace(["app/pages/+page.haml:3:in 'render'"])
    app = Mayu::Server::App.allocate
    app.instance_variable_set(
      :@environment,
      ErrorEnvironment.new(nil, ErrorConfig.new(true))
    )
    request = Request.new("GET", "/", {"accept" => "text/html"}, "")

    response =
      Mayu::Session.stub(:new, ->(**) { raise failure }) { app.call(request) }

    assert_equal(500, response.status)
    body = response.body.join
    assert_includes(body, "RuntimeError: render boom")
    assert_includes(body, "app/pages/+page.haml:3")

    app.instance_variable_set(
      :@environment,
      ErrorEnvironment.new(nil, ErrorConfig.new(false))
    )
    response =
      Mayu::Session.stub(:new, ->(**) { raise failure }) { app.call(request) }

    assert_equal(500, response.status)
    assert_equal("Internal Server Error", response.body.join)
  end

  class BuildErrorProvider
    def entry(name) = name

    def exports(_entry) = raise(ArgumentError, "Invalid attribute list")

    def build_error_report(error) = "Haml parse error: #{error.message}"
  end

  def test_a_build_error_is_rendered_as_its_report_in_development
    app = Mayu::Server::App.allocate
    app.instance_variable_set(
      :@environment,
      ErrorEnvironment.new(BuildErrorProvider.new, ErrorConfig.new(true))
    )

    response = app.call(Request.new("GET", "/", {"accept" => "text/html"}, ""))

    assert_equal(500, response.status)
    assert_equal("Haml parse error: Invalid attribute list", response.body.join)
  end

  def test_a_build_error_is_a_json_500_for_non_browser_requests
    app = Mayu::Server::App.allocate
    app.instance_variable_set(
      :@environment,
      ErrorEnvironment.new(BuildErrorProvider.new, ErrorConfig.new(true))
    )

    response =
      app.call(Request.new("GET", "/", {"accept" => "application/json"}, ""))

    assert_equal(500, response.status)
    assert_includes(response.body.join, "INTERNAL_SERVER_ERROR")
  end

  def test_a_build_error_is_not_rendered_without_render_exceptions
    app = Mayu::Server::App.allocate
    app.instance_variable_set(
      :@environment,
      ErrorEnvironment.new(BuildErrorProvider.new, ErrorConfig.new(false))
    )

    response = app.call(Request.new("GET", "/", {"accept" => "text/html"}, ""))

    assert_equal(500, response.status)
    refute_includes(response.body.join, "Invalid attribute list")
  end

  PageSession = Data.define(:id, :styles, :route_status) do
    def render = "<html></html>"
  end
  PageEnvironment = Data.define(:module_provider, :metrics)
  PageRequest =
    Data.define(:method, :path, :headers, :body, :version) do
      def read = body
    end

  def test_pages_are_served_to_non_browser_clients_without_storing_the_session
    stored, response = start_page("/page", "*/*")

    assert_equal(200, response.status)
    assert_equal("<html></html>", response.body.join)
    assert_equal("Accept", response.headers.to_a.to_h.fetch(:vary))
    assert_empty(stored)
  end

  def test_browser_navigations_store_the_session
    stored, response = start_page("/page", "text/html,*/*;q=0.8")

    assert_equal(200, response.status)
    assert_equal("Accept", response.headers.to_a.to_h.fetch(:vary))
    assert_equal(["page-session"], stored.map(&:id))
  end

  def test_missing_pages_are_a_plain_404_for_non_browser_clients
    stored, response = start_page("/missing.png", "image/*,*/*;q=0.8")

    assert_equal(404, response.status)
    assert_equal("file not found", response.body.join)
    assert_empty(stored)
  end

  def test_missing_pages_render_the_not_found_page_for_browsers
    _stored, response =
      start_page("/missing", "text/html", route_status: 404)

    assert_equal(404, response.status)
    assert_equal("<html></html>", response.body.join)
  end

  class RobotsProvider
    def initialize(robots_txt) = @robots_txt = robots_txt

    def entry(name) = name

    def exports(entry)
      raise KeyError unless entry == "robots.txt" && @robots_txt

      exports = Module.new
      exports.const_set(:Default, @robots_txt)
      exports
    end
  end

  def test_serves_robots_txt_from_the_module_provider
    response = robots_txt_response(RobotsProvider.new("User-agent: *\n"))

    assert_equal(200, response.status)
    headers = response.headers.to_a.to_h
    assert_equal("text/plain; charset=utf-8", headers.fetch(:"content-type"))
    assert_equal(
      Mayu::Server::App::ROBOTS_TXT_CACHE_CONTROL,
      headers.fetch(:"cache-control")
    )
    assert_equal("User-agent: *\n", response.body.join)
  end

  def test_robots_txt_is_a_404_when_the_app_has_none
    response = robots_txt_response(RobotsProvider.new(nil))

    assert_equal(404, response.status)
    assert_equal("file not found", response.body.join)
  end

  RuntimeEnvironment = Data.define(:runtime_init_js_path)

  def script_response(path)
    Dir.mktmpdir("mayu-client") do |root|
      File.write(File.join(root, "init-abc123.js"), "export default null\n")
      File.write(File.join(root, "main-def456.js"), "export default null\n")
      app = Mayu::Server::App.allocate
      app.instance_variable_set(:@client_files, Mayu::Server::StaticFiles.new(root))
      app.instance_variable_set(:@environment, RuntimeEnvironment.new("/.mayu/runtime/init-abc123.js"))

      app.send(:handle_script, Request.new("GET", path, {}, ""))
    end
  end

  # The initializer reads the session id from its URL's fragment, which a
  # cached module would keep from an earlier page.
  def test_serves_the_client_initializer_uncached
    response = script_response("/.mayu/runtime/init-abc123.js")

    assert_equal(200, response.status)
    headers = response.headers.to_a.to_h
    assert_includes(Array(headers.fetch(:"content-type")), "text/javascript")
    assert_includes(Array(headers.fetch(:"cache-control")), "no-store")
    assert_equal("export default null\n", Brotli.inflate(response.body.join))
  end

  def test_serves_other_runtime_scripts_with_immutable_caching
    response = script_response("/.mayu/runtime/main-def456.js")

    headers = response.headers.to_a.to_h
    assert_includes(Array(headers.fetch(:"cache-control")), Mayu::Server::App::ASSET_CACHE_CONTROL)
  end

  def test_link_header_keeps_klenod_asset_urls_absolute
    app = Mayu::Server::App.allocate
    app.instance_variable_set(
      :@environment,
      Environment.new(nil)
    )

    header =
      app.send(:link_header, Session.new(%w[/.mayu/assets/page.css legacy.css]))

    assert_includes(header, "</.mayu/assets/page.css>; rel=preload; as=style")
    assert_includes(header, "</.mayu/assets/legacy.css>; rel=preload; as=style")
    refute_includes(header, "/.mayu/assets//.mayu/assets/")
  end

  def test_transfer_admission_is_rechecked_after_reading_the_request_body
    app = Mayu::Server::App.allocate
    request = Object.new
    request.define_singleton_method(:read) do
      app.instance_variable_set(:@stopping, true)
      "not decrypted because shutdown started"
    end
    response = app.send(:handle_session_transfer, request, "session")
    assert_equal(503, response.status)
    assert_equal("Server is stopping", response.read)
  end

  def test_a_transfer_that_can_not_be_restored_asks_the_client_to_start_over
    app = Mayu::Server::App.allocate
    app.instance_variable_set(:@environment, Struct.new(:marshaller).new(nil))
    cookies = Object.new
    cookies.define_singleton_method(:get_token_cookie_value) { |_request| "token" }
    app.instance_variable_set(:@cookies, cookies)
    request = Object.new
    request.define_singleton_method(:read) { "state" }
    transfer = Object.new
    transfer.define_singleton_method(:authenticate!) { |**| self }
    transfer.define_singleton_method(:resume) { |_environment| raise ArgumentError, "undefined class" }

    response =
      Mayu::Session::TransferState.stub(:decrypt, transfer) do
        app.send(:handle_session_transfer, request, "session")
      end

    assert_equal(422, response.status)
    assert_includes(response.read, "SESSION_RESTORE_FAILED")
  end

  def test_session_events_are_acknowledged_with_an_empty_204
    Async do
      app = Mayu::Server::App.allocate
      session = Object.new
      session.define_singleton_method(:wait) {}
      sessions = Object.new
      sessions.define_singleton_method(:authenticate!) { |_id, _token| session }
      app.instance_variable_set(:@sessions, sessions)
      cookies = Object.new
      cookies.define_singleton_method(:get_token_cookie_value) { |_request| "token" }
      cookies.define_singleton_method(:set_token_cookie_header) { |_session| {} }
      app.instance_variable_set(:@cookies, cookies)
      body = Object.new
      body.define_singleton_method(:close) {}
      request = Struct.new(:headers, :body).new({}, body)

      response =
        Mayu::Server::EventStream.stub(:each_incoming_message, ->(_request) {}) do
          app.send(:handle_session_event, request, "session")
        end

      assert_equal(204, response.status)
      assert_nil(response.body)
    end.wait
  end

  def test_stopping_a_session_closes_its_patch_stream
    Async do |task|
      app = Mayu::Server::App.allocate
      app.instance_variable_set(:@body_barrier, Async::Barrier.new(parent: task))
      app.instance_variable_set(:@streams, {})
      cookies = Object.new
      cookies.define_singleton_method(:set_token_cookie_header) { |_session| {} }
      app.instance_variable_set(:@cookies, cookies)

      session = StreamSession.new
      request = Struct.new(:headers).new({})
      response = app.send(:run_session_stream, request, session)

      session.wait_until_started
      session.stop

      chunks = []
      task.with_timeout(0.5) do
        while (chunk = response.body.read)
          chunks << chunk
        end
      end
      refute_empty(chunks)

      inflater = Zlib::Inflate.new(-Zlib::MAX_WBITS)
      bootstrap = MessagePack.unpack(inflater.inflate(chunks.join))
      assert_equal(%w[Initialize SetListener], bootstrap.map(&:first))
      refute_includes(bootstrap.map(&:first), "Batch")
    ensure
      inflater&.close
      response&.body&.close
      app&.instance_variable_get(:@body_barrier)&.stop
    end.wait
  end

  private

  def dispatch(method, path, headers)
    app = Mayu::Server::App.allocate
    app.instance_variable_set(
      :@environment,
      Environment.new(provider)
    )
    app.send(:handle_provider_route, Request.new(method, path, headers, ""))
  end

  def start_page(path, accept, route_status: 200)
    router = Module.new
    router.define_singleton_method(:match) do |match_path|
      Match.new(Page, nil, {}) if match_path == "/page"
    end
    exports = Module.new
    exports.const_set(:Default, router)

    counter = Object.new
    counter.define_singleton_method(:increment) {}
    metrics = Struct.new(:session_starts_total).new(counter)

    stored = []
    sessions = Object.new
    sessions.define_singleton_method(:store) { |session| stored << session }

    cookies = Object.new
    cookies.define_singleton_method(:set_token_cookie_header) { |_session| {} }

    app = Mayu::Server::App.allocate
    app.instance_variable_set(
      :@environment,
      PageEnvironment.new(Provider.new(exports), metrics)
    )
    app.instance_variable_set(:@sessions, sessions)
    app.instance_variable_set(:@cookies, cookies)

    session = PageSession.new("page-session", [], route_status)
    request = PageRequest.new("GET", path, {"accept" => accept}, "", "HTTP/2")
    response = Mayu::Session.stub(:new, ->(**) { session }) { app.call(request) }

    [stored, response]
  end

  def robots_txt_response(provider)
    app = Mayu::Server::App.allocate
    app.instance_variable_set(:@environment, Environment.new(provider))
    app.call(Request.new("GET", "/robots.txt", {}, ""))
  end

  def provider
    router = Module.new
    router.define_singleton_method(:match) do |_path|
      Match.new(Page, Handler, {"id" => "42"})
    end
    exports = Module.new
    exports.const_set(:Default, router)
    Provider.new(exports)
  end
end
