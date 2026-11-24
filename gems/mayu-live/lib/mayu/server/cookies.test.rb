#!/usr/bin/env ruby -rbundler/setup
# frozen_string_literal: true

require "minitest/autorun"
require "minitest/mock"
require "time"

require_relative "cookies"

class Mayu::Server::CookiesTest < Minitest::Test
  Session = Data.define(:id, :token)

  # An expiry would run out while the page is open: the cookie is only set
  # again when a stream opens, and a page that reconnects without it loses
  # its session.
  def test_the_token_cookie_lasts_as_long_as_the_browser_session
    value = Mayu::Server::Cookies.new.set_token_cookie_value(Session.new("session", "token"))

    assert_equal(
      "mayu-token=token; path=/.mayu/session/session; secure; HttpOnly; SameSite=Strict",
      value
    )
  end
end
