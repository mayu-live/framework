# frozen_string_literal: true

#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "prometheus/client/formats/text"

module Mayu
  module Metrics
    class Server
      def self.run(listen:)
      end

      def initialize(listen:, registry: Prometheus::Client.registry)
        @registry = registry

        @server =
          Async::HTTP::Server.new(
            self,
            Async::HTTP::Endpoint.new(URI.parse(listen)),
            protocol: Async::HTTP::Protocol::HTTP11
          )
      end

      def run
        puts "\e[32mStarting metrics server on \e[34m#{@server.endpoint.url}\e[0m"
        @server.run
      end

      def call(request)
        case request.path
        in "/" | "/metrics"
          render_metrics
        else
          render_404
        end
      end

      private

      def render_metrics
        body = Prometheus::Client::Formats::Text.marshal(@registry)

        Protocol::HTTP::Response[200, {"content-type": "text/plain"}, [body]]
      end

      def render_404
        Protocol::HTTP::Response[
          404,
          {"content-type": "text/plain"},
          ["Not found"]
        ]
      end
    end
  end
end
