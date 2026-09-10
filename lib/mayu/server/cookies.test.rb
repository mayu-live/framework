#!/usr/bin/env ruby -rbundler/setup
# frozen_string_literal: true

require "minitest/autorun"
require "minitest/mock"
require "time"

require_relative "cookies"

class Mayu::Server::CookiesTest < Minitest::Test
  Session = Data.define(:id, :token)

  def test_cookie_expiration_uses_the_configured_timeout
    now = Time.utc(2026, 9, 10, 12, 0, 0)
    cookies = Mayu::Server::Cookies.new(timeout_seconds: 17)
    session = Session.new("session", "token")

    value = Time.stub(:now, now) { cookies.set_token_cookie_value(session) }

    assert_includes(value, "expires=#{(now + 17).httpdate}")
  end
end
