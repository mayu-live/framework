#!/usr/bin/env -S falcon host
# frozen_string_literal: true

require "toml-rb"

load :rack, :supervisor

ENV["MAYU_ENV"] = "production"

config =
  TomlRB.load_file("example/mayu.toml", symbolize_keys: true).fetch(:prod, {})

hostname = config.fetch(:hostname, "localhost")
port = config.fetch(:port, 3000)

rack(hostname) do
  endpoint(
    Async::HTTP::Endpoint.parse("http://0.0.0.0:#{port}").with(
      protocol: Async::HTTP::Protocol::HTTP2
    )
  )
end

supervisor
