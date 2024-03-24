#!/usr/bin/env ruby -rbundler/setup
# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "minitest/autorun"

require_relative "routes"

class Mayu::Routes::Test < Minitest::Test
  def test_router
    router = setup_router

    match = router.match("/")
    assert_equal(%w[layout.haml], match.route.layouts)
    assert_equal("page.haml", match.route.views.page)

    match = router.match("/subpage")
    assert_equal(%w[layout.haml], match.route.layouts)
    assert_equal("subpage/page.haml", match.route.views.page)

    match = router.match("/subpage2")
    assert_equal(%w[layout.haml subpage2/layout.haml], match.route.layouts)
    assert_equal("subpage2/page.haml", match.route.views.page)

    match = router.match("/subpage2/hello")
    assert_equal(%w[layout.haml subpage2/layout.haml], match.route.layouts)
    assert_equal("subpage2/hello/page.haml", match.route.views.page)
  end

  def test_params
    router = setup_router

    match = router.match("/params/123")

    assert_equal({ id: "123" }, match.params)
    assert_equal(%w[layout.haml], match.route.layouts)
    assert_equal("params/:id/page.haml", match.route.views.page)
  end

  def test_query
    router = setup_router

    match = router.match("/subpage2/hello?foo=bar")
    assert_equal({ foo: "bar" }, match.query)

    match = router.match("/subpage2/hello?values[]=foo&values[]=bar")
    assert_equal({ values: %w[foo bar] }, match.query)

    match = router.match("/subpage2/hello?things[0]=foo&things[1]=bar")
    assert_equal({ things: { 0 => "foo", 1 => "bar" } }, match.query)
  end

  def test_not_found
    skip "TODO: Fix this implementation"
    router = setup_router

    match = router.match("/non-existant-route")
    assert(match, "match should return some sort of route object")
  end

  private

  def setup_router
    Mayu::Routes::Router.build(File.join(__dir__, "__test__", "routes"))
  end
end
