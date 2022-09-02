# typed: true

require "prometheus/client/registry"
require "prometheus/middleware/collector"
require "prometheus/middleware/exporter"

module Mayu
  class Metrics
    class PrometheusRegistry < Prometheus::Client::Registry
      extend T::Sig

      # Prevent the following error:
      # Prometheus::Client::Registry::AlreadyRegisteredError: http_server_requests_total has already been registered
      sig do
        params(metric: Prometheus::Client::Metric).returns(
          Prometheus::Client::Metric
        )
      end
      def register(metric)
        name = metric.name
        @mutex.synchronize do
          metric =
            T.let(@metrics[name.to_sym] ||= metric, Prometheus::Client::Metric)
        end
        metric
      end
    end

    module Middleware
      class Exporter < Prometheus::Middleware::Exporter
      end

      class Collector < Prometheus::Middleware::Collector
        extend T::Sig

        sig { params(path: String).returns(String) }
        def strip_ids_from_path(path)
          # Strip sha256 hashes
          super.gsub(%r{/[[:xdigit:]]{64}(?=\.|/|$)}, '/:hash\\1')
        end
      end
    end
  end
end