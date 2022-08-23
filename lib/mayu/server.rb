# typed: strict

require "rack"
require "prometheus/middleware/exporter"
require_relative "server/cluster"
require_relative "server/worker"
require_relative "metrics"

module Mayu
  module Server
    extend T::Sig

    sig do
      params(cluster: Cluster, metrics: Metrics, config: Config).returns(
        Rack::Builder
      )
    end
    def self.build(cluster:, metrics:, config:)
      Worker.start(cluster:, metrics:, config:)

      Rack::Builder.new do
        T.bind(self, Rack::Builder)

        use Rack::CommonLogger
        use Rack::Deflater
        use Prometheus::Middleware::Exporter

        use Rack::Static, urls: ["/public"]

        run ->(req) {
              [
                200,
                { "Content-Type" => "text/plain" },
                ["OK #{req["PATH_INFO"]}"]
              ]
            }
      end
    end
  end
end
