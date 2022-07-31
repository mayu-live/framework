#!/usr/bin/env -S falcon host
# frozen_string_literal: true

load :rack, :supervisor

hostname = "mayu.fly.dev"

rack(hostname) do
	endpoint Async::HTTP::Endpoint.parse('http://0.0.0.0:3000')
		.with(protocol: Async::HTTP::Protocol::HTTP2)
end

supervisor
