# typed: strict

require "prometheus/client"
require_relative "metrics/prometheus"

module Mayu
  class Metrics
    extend T::Sig

    sig { returns(Prometheus::Client::Counter) }
    attr_reader :worker_queue_messages
    sig { returns(Prometheus::Client::Counter) }
    attr_reader :session_heartbeats
    sig { returns(Prometheus::Client::Counter) }
    attr_reader :session_callbacks
    sig { returns(Prometheus::Client::Counter) }
    attr_reader :session_connect
    sig { returns(Prometheus::Client::Counter) }
    attr_reader :session_disconnect
    sig { returns(Prometheus::Client::Counter) }
    attr_reader :session_timeout
    sig { returns(Prometheus::Client::Gauge) }
    attr_reader :session_count
    sig { returns(Prometheus::Client::Gauge) }
    attr_reader :session_limit

    sig do
      params(
        cluster: Server::Cluster,
        prometheus: Prometheus::Client::Registry
      ).void
    end
    def initialize(cluster:, prometheus: Prometheus::Client.registry)
      preset_labels = {
        region: cluster.region,
        alloc_id: cluster.alloc_id,
        app_name: cluster.app_name
      }

      @worker_queue_messages =
        T.let(
          prometheus.counter(
            :worker_queue_messages,
            docstring: "Number of messages received on the worker queue",
            labels: [:event, *preset_labels.keys],
            preset_labels:
          ),
          Prometheus::Client::Counter
        )

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

      @session_connect =
        T.let(
          prometheus.counter(
            :session_connect,
            docstring: "Number of connects",
            labels: [*preset_labels.keys],
            preset_labels:
          ),
          Prometheus::Client::Counter
        )

      @session_disconnect =
        T.let(
          prometheus.counter(
            :session_disconnect,
            docstring: "Number of disconnects",
            labels: [*preset_labels.keys],
            preset_labels:
          ),
          Prometheus::Client::Counter
        )

      @session_timeout =
        T.let(
          prometheus.counter(
            :session_timeout,
            docstring: "Number of timeouts",
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

      @session_limit =
        T.let(
          prometheus.gauge(
            :session_limit,
            docstring: "Max number of sessions",
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
