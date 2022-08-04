#!/usr/bin/env ruby

require "bundler/setup"
require "pry"
require "async"
require "async/barrier"
require "async/http/internet"

TOPICS = %w[ruby python rust]

Async do
  internet = Async::HTTP::Internet.new
  barrier = Async::Barrier.new

  60.times do |x|
    sleep 1.0
    barrier.async do
      response = internet.get("https://mayu.live", [%w[accept text/html]])
      body = response.read
      match = body.match(/live\.js\?(.*?)"/)
      unless match
        puts body
        exit
        raise "Could not find session id"
      end
      session_id = match[1]
      cookie_name, cookie_value =
        response.headers["set-cookie"].last.split(";").first.split("=")
      raise "Bad cookie name" unless cookie_name == "mayu-session-#{session_id}"
      sleep 0.1
      response =
        internet.get(
          "https://mayu.live/__mayu/events/#{session_id}",
          [["cookie", "#{cookie_name}=#{cookie_value};"]]
        )
      connection = response.connection

      response.each { |chunk| p [x, chunk.length] }
    end
  end

  # Ensure we wait for all requests to complete before continuing:
  barrier.wait
ensure
  internet&.close
end
