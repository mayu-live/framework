# typed: strict

require "prometheus/client"
require_relative "metrics/prometheus"

module Mayu
  class Metrics
    extend T::Sig

    sig { returns(Prometheus::Client::Counter) }
    attr_reader :session_callbacks
    sig { returns(Prometheus::Client::Gauge) }
    attr_reader :session_count

    sig do
      params(
        config: Configuration,
        prometheus: Prometheus::Client::Registry
      ).void
    end
    def initialize(config:, prometheus: Prometheus::Client.registry)
      preset_labels = {
        region: config.region,
        alloc_id: config.alloc_id,
        app_name: config.app_name
      }

      @session_heartbeats =
        T.let(
          prometheus.counter(
            :session_ping,
            docstring: "Total number of heartbeats",
            labels: [*preset_labels.keys],
            preset_labels:
          ),
          Prometheus::Client::Counter
        )

      @session_callbacks =
        T.let(
          prometheus.counter(
            :session_callbacks,
            docstring: "Number of callbacks called",
            labels: [*preset_labels.keys],
            preset_labels:
          ),
          Prometheus::Client::Counter
        )

      @session_count =
        T.let(
          prometheus.gauge(
            :session_count,
            docstring: "Number of sessions",
            labels: [*preset_labels.keys],
            preset_labels:,
            store_settings: {
              aggregation: :sum
            }
          ),
          Prometheus::Client::Gauge
        )
    end
  end
end
