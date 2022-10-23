# typed: strict

module Mayu
  class AppMetrics < T::Struct
    extend T::Sig

    const :error_count, Prometheus::Client::Counter
    const :session_init_count, Prometheus::Client::Counter
    const :session_timeout_count, Prometheus::Client::Counter
    const :session_ping_count, Prometheus::Client::Counter
    const :session_callback_count, Prometheus::Client::Counter
    const :session_navigate_count, Prometheus::Client::Counter
    const :session_count, Prometheus::Client::Gauge
    const :vnode_patch_times, Prometheus::Client::Summary

    sig do
      params(
        registry: Prometheus::Client::Registry,
        preset_labels: String
      ).returns(T.attached_class)
    end
    def self.setup(registry, **preset_labels)
      store_settings =
        if Prometheus::Client.config.data_store.is_a?(
             Prometheus::Client::DataStores::Synchronized
           )
          {}
        else
          { aggregation: :sum }
        end

      new(
        session_init_count:
          registry.counter(
            :mayu_session_init_count,
            docstring: "Total number of inits",
            labels: [*preset_labels.keys],
            preset_labels:
          ),
        session_ping_count:
          registry.counter(
            :mayu_session_ping_count,
            docstring: "Total number of pings",
            labels: [*preset_labels.keys],
            preset_labels:
          ),
        session_callback_count:
          registry.counter(
            :mayu_session_callback_count,
            docstring: "Total number of callbacks",
            labels: [*preset_labels.keys],
            preset_labels:
          ),
        session_navigate_count:
          registry.counter(
            :mayu_session_navigate_count,
            docstring: "Total number of navigates",
            labels: [*preset_labels.keys],
            preset_labels:
          ),
        session_timeout_count:
          registry.counter(
            :mayu_session_timeout_count,
            docstring: "Total number of timeouts",
            labels: [*preset_labels.keys],
            preset_labels:
          ),
        error_count:
          registry.counter(
            :mayu_error_count,
            docstring: "Total number errors",
            labels: [*preset_labels.keys],
            preset_labels:
          ),
        session_count:
          registry.gauge(
            :mayu_session_count,
            docstring: "Number of active sessions",
            labels: [*preset_labels.keys],
            preset_labels:,
            store_settings:
          ),
        vnode_patch_times:
          registry.summary(
            :mayu_vnode_patch_times,
            docstring: "VNode patch times",
            labels: [:vnode_type, *preset_labels.keys],
            preset_labels:
          )
      )
    end
  end
end
