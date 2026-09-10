#!/usr/bin/env ruby -rbundler/setup
# frozen_string_literal: true

require "minitest/autorun"
require "async/http/protocol"

require_relative "app"
require_relative "../runtime/patches"

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
  Environment = Data.define(:module_provider, :init_js_body, :runtime_js_path)
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
  Request = Data.define(:method, :path, :headers, :body) { def read = body }

  class StreamSession
    DomIdTree = Data.define(:value) { def serialize = value }

    attr_reader :id, :dom_id_tree

    def initialize
      @id = "test-session"
      @dom_id_tree = DomIdTree.new([])
      @started = Async::Promise.new
      @stopped = Async::Promise.new
    end

    def running? = false
    def transferring? = false

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

    def dequeue_patch
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
      Environment.new(provider, nil, nil)
    )

    response =
      app.call(
        Request.new("GET", "/api", {"accept" => "application/json"}, "")
      )

    assert_equal(403, response.status)
    refute_nil(provider.rewritten_error)
    assert_equal(
      ["app:/pages/api/+route.rb:3"],
      provider.rewritten_error.backtrace
    )
  end

  def test_serves_the_shared_client_initializer_without_a_session
    app = Mayu::Server::App.allocate
    app.instance_variable_set(
      :@environment,
      Environment.new(nil, "export default null\n", nil)
    )

    response =
      app.send(:handle_init_js, Request.new("GET", "/.mayu/init.js", {}, ""))

    assert_equal(200, response.status)
    assert_equal(
      ["application/javascript"],
      response.headers.to_h.fetch(:"content-type")
    )
    assert_equal("export default null\n", response.body.read)
  end

  def test_link_header_keeps_klenod_asset_urls_absolute
    app = Mayu::Server::App.allocate
    app.instance_variable_set(
      :@environment,
      Environment.new(nil, nil, "/.mayu/runtime/client.js")
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
    ensure
      response&.body&.close
      app&.instance_variable_get(:@body_barrier)&.stop
    end.wait
  end

  private

  def dispatch(method, path, headers)
    app = Mayu::Server::App.allocate
    app.instance_variable_set(
      :@environment,
      Environment.new(provider, nil, nil)
    )
    app.send(:handle_provider_route, Request.new(method, path, headers, ""))
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
