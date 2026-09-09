# frozen_string_literal: true

require "minitest/autorun"

require_relative "route"

class Mayu::RouteTest < Minitest::Test
  FakeRequest = Data.define(:method, :path, :headers, :body) { def read = body }

  def test_wraps_an_async_style_request_for_a_route_handler
    request =
      FakeRequest.new(
        "POST",
        "/api/books/42?format=json&locale=en",
        {"content-type" => "application/json"},
        '{"title":"Klenod"}'
      )

    wrapped = Mayu::Route::Request.from_async(request, params: {"id" => "42"})

    assert_equal("POST", wrapped.method)
    assert_equal("/api/books/42", wrapped.path)
    assert_equal({"content-type" => "application/json"}, wrapped.headers)
    assert_equal('{"title":"Klenod"}', wrapped.body)
    assert_equal({id: "42"}, wrapped.params)
    assert_equal({"format" => "json", "locale" => "en"}, wrapped.query)
  end
end
