#!/usr/bin/env ruby -rbundler/setup
# frozen_string_literal: true

require "minitest/autorun"
require "minitest/mock"
require "time"

require_relative "cookies"
require_relative "../session/token"
require "protocol/http/headers"

class Mayu::Server::CookiesTest < Minitest::Test
  Session = Data.define(:id, :token)

  def test_transport_cookie_can_follow_application_cookies
    token = "a" * 64
    headers = Protocol::HTTP::Headers[[["cookie", "application=value; mayu-token=#{token}"], ["cookie", "other=value"]]]
    request = Struct.new(:headers).new(headers)
    assert_equal token, Mayu::Server::Cookies.new.get_token_cookie_value(request)
  end

  def test_cookie_expiration_uses_the_configured_timeout
    now = Time.utc(2026, 9, 10, 12, 0, 0)
    cookies = Mayu::Server::Cookies.new(timeout_seconds: 17)
    session = Session.new("session", "token")

    value = Time.stub(:now, now) { cookies.set_token_cookie_value(session) }

    assert_includes(value, "expires=#{(now + 17).httpdate}")
  end
end
