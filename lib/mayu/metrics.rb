# typed: strict

require "prometheus/client"
require_relative "metrics/prometheus"
require "prometheus/client/data_stores/direct_file_store"

module Mayu
  class Metrics
    extend T::Sig

    sig { returns(Prometheus::Client::Counter) }
    attr_reader :error_count
    sig { returns(Prometheus::Client::Counter) }
    attr_reader :session_init_count
    sig { returns(Prometheus::Client::Counter) }
    attr_reader :session_navigate_count
    sig { returns(Prometheus::Client::Counter) }
    attr_reader :session_ping_count
    sig { returns(Prometheus::Client::Counter) }
    attr_reader :session_callback_count
    sig { returns(Prometheus::Client::Summary) }
    attr_reader :vnode_patch_times

    sig { params(config: Configuration).void }
    def self.setup(config)
      return if $mayu_metrics_configured
      $mayu_metrics_configured = true

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

      @error_count =
        T.let(
          prometheus.counter(
            :mayu_error_count,
            docstring: "Total number of errors",
            labels: [:type, *preset_labels.keys],
            preset_labels:
          ),
          Prometheus::Client::Counter
        )

      @session_init_count =
        T.let(
          prometheus.counter(
            :mayu_session_init_count,
            docstring: "Total number of inits",
            labels: [*preset_labels.keys],
            preset_labels:
          ),
          Prometheus::Client::Counter
        )

      @session_navigate_count =
        T.let(
          prometheus.counter(
            :mayu_session_navigate_count,
            docstring: "Total number of navigations",
            labels: [*preset_labels.keys],
            preset_labels:
          ),
          Prometheus::Client::Counter
        )

      @session_ping_count =
        T.let(
          prometheus.counter(
            :mayu_session_ping_count,
            docstring: "Total number of pings",
            labels: [*preset_labels.keys],
            preset_labels:
          ),
          Prometheus::Client::Counter
        )

      @session_callback_count =
        T.let(
          prometheus.counter(
            :mayu_session_callback_count,
            docstring: "Number of callbacks called",
            labels: [*preset_labels.keys],
            preset_labels:
          ),
          Prometheus::Client::Counter
        )

      @vnode_patch_times =
        T.let(
          prometheus.summary(
            :mayu_vnode_patch_times,
            docstring: "VNode patch times",
            labels: [:vnode_type, *preset_labels.keys],
            preset_labels:
          ),
          Prometheus::Client::Summary
        )

      # store_settings =
      #   case Prometheus::Client.config.data_store
      #   when Prometheus::Client::DataStores::DirectFileStore
      #     { aggregation: :sum }
      #   else
      #     {}
      #   end
      #
      # @session_count =
      #   T.let(
      #     prometheus.gauge(
      #       :session_count,
      #       docstring: "Number of sessions",
      #       labels: [*preset_labels.keys],
      #       preset_labels:,
      #       store_settings:
      #     ),
      #     Prometheus::Client::Gauge
      #   )
    end
  end
end
