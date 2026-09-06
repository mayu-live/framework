#!/usr/bin/env ruby -rbundler/setup
# frozen_string_literal: true

require "minitest/autorun"
require "async/http/protocol"

require_relative "app"

class Mayu::Server::AppTest < Minitest::Test
  class Page < Mayu::Component::Base
  end

  class Handler < Mayu::Route
    def GET(request)
      [
        200,
        { "content-type" => "application/json" },
        request.query.fetch("format")
      ]
    end

    def PUT(request)
      [202, {}, request.params.fetch(:id)]
    end
  end

  Match = Data.define(:page, :handler, :params)
  Environment = Data.define(:module_provider)
  Provider =
    Data.define(:exports_module) do
      def entry(name) = name

      def exports(entry)
        raise KeyError unless entry == "virtual:router"

        exports_module
      end
    end
  Request = Data.define(:method, :path, :headers, :body) { def read = body }

  def test_html_page_requests_do_not_dispatch_the_handler
    response = dispatch("GET", "/api/42", { "accept" => "text/html" })

    assert_nil(response)
  end

  def test_non_html_requests_dispatch_the_handler_with_route_data
    response =
      dispatch("GET", "/api/42?format=json", { "accept" => "application/json" })

    assert_equal(200, response.status)
    assert_equal("json", response.body.read)
    assert_equal(["accept"], response.headers.to_h.fetch("vary"))
  end

  def test_mutating_requests_dispatch_the_handler_even_when_html_is_accepted
    response = dispatch("PUT", "/api/42", { "accept" => "text/html" })

    assert_equal(202, response.status)
    assert_equal("42", response.body.read)
  end

  def test_html_post_requests_keep_the_live_page_path
    response = dispatch("POST", "/api/42", { "accept" => "text/html" })

    assert_nil(response)
  end

  def test_unsupported_handler_methods_return_405
    response = dispatch("DELETE", "/api/42", { "accept" => "application/json" })

    assert_equal(405, response.status)
    assert_equal(%w[GET PUT], response.headers.to_h.fetch("allow"))
  end

  private

  def dispatch(method, path, headers)
    app = Mayu::Server::App.allocate
    app.instance_variable_set(:@environment, Environment.new(provider))
    app.send(:handle_provider_route, Request.new(method, path, headers, ""))
  end

  def provider
    router = Module.new
    router.define_singleton_method(:match) do |_path|
      Match.new(Page, Handler, { "id" => "42" })
    end
    exports = Module.new
    exports.const_set(:Default, router)
    Provider.new(exports)
  end
end
