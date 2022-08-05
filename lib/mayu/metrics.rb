# typed: true
#
require "prometheus/client/registry"
require 'prometheus/middleware/collector'
require 'prometheus/middleware/exporter'

module Mayu
  module Metrics
    class PrometheusRegistry < Prometheus::Client::Registry
      extend T::Sig
      # Prevent the following error:
      # Prometheus::Client::Registry::AlreadyRegisteredError: http_server_requests_total has already been registered
      def register(metric)
        name = metric.name
        @mutex.synchronize do
          metric = @metrics[name.to_sym] ||= metric
        end
        metric
      end
    end

    module Middleware
      class Exporter < Prometheus::Middleware::Exporter
      end

      class Collector < Prometheus::Middleware::Collector
        def strip_ids_from_path(path)
          super.gsub(%r{/[[:xdigit:]]{64}(?=\.|/|$)}, '/:hash\\1')
        end
      end
    end
  end
end
