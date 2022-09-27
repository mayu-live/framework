# typed: strict

require "prometheus/client"
require_relative "metrics/prometheus"
require "prometheus/client/data_stores/direct_file_store"

module Mayu
  class Metrics
    extend T::Sig

    sig { returns(Prometheus::Client::Counter) }
    attr_reader :session_callbacks
    sig { returns(Prometheus::Client::Gauge) }
    attr_reader :session_count

    sig { params(config: Configuration).void }
    def self.setup(config)
      Prometheus::Client.config.data_store =
        Prometheus::Client::DataStores::DirectFileStore.new(
          dir: File.join(config.root, "tmp", "prometheus")
        )

      new(config:)
    end

    sig do
      params(
        config: Configuration,
        prometheus: Prometheus::Client::Registry
      ).void
    end
    def initialize(config:, prometheus: Prometheus::Client.registry)
      preset_labels = {
        region: config.instance.region,
        alloc_id: config.instance.alloc_id,
        app_name: config.instance.app_name
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

      store_settings =
        case Prometheus::Client.config.data_store
        when Prometheus::Client::DataStores::DirectFileStore
          { aggregation: :sum }
        else
          {}
        end

      @session_count =
        T.let(
          prometheus.gauge(
            :session_count,
            docstring: "Number of sessions",
            labels: [*preset_labels.keys],
            preset_labels:,
            store_settings:
          ),
          Prometheus::Client::Gauge
        )
    end
  end
end
