# typed: strict
# frozen_string_literal: true

require "prometheus/client"
require "prometheus/client/data_stores/direct_file_store"

module Mayu
  module Server
    class PrometheusServer
      extend T::Sig

      sig { params(config: Configuration).void }
      def self.start(config)
        exporter =
          Prometheus::Middleware::Exporter.new(->(_env) { [200, {}, "ok"] })

        protocol = Async::HTTP::Protocol::HTTP1
        endpoint =
          T.cast(
            Async::HTTP::Endpoint.parse(
              "http://#{config.metrics.host}:#{config.metrics.port}",
              reuse_port: true
            ),
            Async::HTTP::Endpoint
          )

        Console.logger.info(self, "Starting prometheus on #{endpoint.to_url}")

        server =
          Async::HTTP::Server.for(endpoint, protocol: protocol) do |request|
            exporter.call("PATH_INFO" => request.path) => [
              status,
              headers,
              body
            ]

            Protocol::HTTP::Response[status, headers, body]
          end

        server.run
      end

      sig { params(config: Configuration).void }
      def self.setup(config)
        Prometheus::Client.config.data_store =
          Prometheus::Client::DataStores::DirectFileStore.new(
            dir: File.join(config.root, "tmp", "prometheus")
          )
      end
    end
  end
end
