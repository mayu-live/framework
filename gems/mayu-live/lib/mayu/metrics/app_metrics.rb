# frozen_string_literal: true

#
# Copyright Andrés Alin <andreas.alin@gmail.com>
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

module Mayu
  module Metrics
    AppMetrics =
      Data.define(
        :active_sessions,
        :session_starts_total,
        :session_timeouts_total,
        :session_pings_total,
        :callback_events_total,
        :callback_queue_duration_ms,
        :callback_handler_duration_ms,
        :navigations_total,
        :command_batches_total,
        :command_batch_commands_total,
        :command_batch_uncompressed_bytes_total,
        :command_batch_compressed_bytes_total,
        :component_mounts_total,
        :component_render_duration_ms,
        :component_reconcile_duration_ms,
        :replace_children_ids_total,
        :reconcile_continuations_total
      ) do
        def self.setup(registry, **preset_labels)
          gauge_store_settings =
            if Prometheus::Client.config.data_store.is_a?(
                 Prometheus::Client::DataStores::Synchronized
               )
              {}
            else
              {aggregation: :sum}
            end

          new(
            active_sessions:
              registry.gauge(
                :mayu_active_sessions,
                docstring: "Number of currently active sessions",
                labels: [*preset_labels.keys],
                preset_labels:,
                store_settings: gauge_store_settings
              ),
            session_starts_total:
              registry.counter(
                :mayu_session_starts_total,
                docstring: "Total number of sessions started",
                labels: [*preset_labels.keys],
                preset_labels:
              ),
            session_timeouts_total:
              registry.counter(
                :mayu_session_timeouts_total,
                docstring: "Total number of sessions timed out",
                labels: [*preset_labels.keys],
                preset_labels:
              ),
            session_pings_total:
              registry.counter(
                :mayu_session_pings_total,
                docstring: "Total number of session pings",
                labels: [*preset_labels.keys],
                preset_labels:
              ),
            callback_events_total:
              registry.counter(
                :mayu_callback_events_total,
                docstring: "Total number of callback events handled",
                labels: [:component, :method, *preset_labels.keys],
                preset_labels:
              ),
            callback_queue_duration_ms:
              registry.summary(
                :mayu_callback_queue_duration_milliseconds,
                docstring: "Time callbacks wait before their component can handle them in milliseconds",
                labels: [:component, :method, *preset_labels.keys],
                preset_labels:
              ),
            callback_handler_duration_ms:
              registry.summary(
                :mayu_callback_handler_duration_milliseconds,
                docstring: "Time spent running callback handlers in milliseconds",
                labels: [:component, :method, *preset_labels.keys],
                preset_labels:
              ),
            navigations_total:
              registry.counter(
                :mayu_navigations_total,
                docstring: "Total number of client-side navigations handled",
                labels: [*preset_labels.keys],
                preset_labels:
              ),
            command_batches_total:
              registry.counter(
                :mayu_command_batches_total,
                docstring: "Total command batches written to session streams",
                labels: [*preset_labels.keys],
                preset_labels:
              ),
            command_batch_commands_total:
              registry.counter(
                :mayu_command_batch_commands_total,
                docstring: "Total commands written to session streams",
                labels: [*preset_labels.keys],
                preset_labels:
              ),
            command_batch_uncompressed_bytes_total:
              registry.counter(
                :mayu_command_batch_uncompressed_bytes_total,
                docstring: "Total MessagePack bytes in command batches before stream compression",
                labels: [*preset_labels.keys],
                preset_labels:
              ),
            command_batch_compressed_bytes_total:
              registry.counter(
                :mayu_command_batch_compressed_bytes_total,
                docstring: "Total compressed bytes in command batches written to session streams",
                labels: [*preset_labels.keys],
                preset_labels:
              ),
            component_mounts_total:
              registry.counter(
                :mayu_component_mounts_total,
                docstring: "Total number of component mounts",
                labels: [:component, *preset_labels.keys],
                preset_labels:
              ),
            component_reconcile_duration_ms:
              registry.summary(
                :mayu_component_reconcile_duration_milliseconds,
                docstring: "Time spent reconciling a component's rendered children in milliseconds",
                labels: [:component, *preset_labels.keys],
                preset_labels:
              ),
            component_render_duration_ms:
              registry.summary(
                :mayu_component_render_duration_milliseconds,
                docstring: "Time spent running a component's render method in milliseconds",
                labels: [:component, *preset_labels.keys],
                preset_labels:
              ),
            replace_children_ids_total:
              registry.counter(
                :mayu_replace_children_ids_total,
                docstring: "Total child IDs sent in ReplaceChildren commands",
                labels: [:tag_name, *preset_labels.keys],
                preset_labels:
              ),
            reconcile_continuations_total:
              registry.counter(
                :mayu_reconcile_continuations_total,
                docstring: "Total reconciliation passes continued after exceeding the update budget",
                labels: [:tag_name, *preset_labels.keys],
                preset_labels:
              )
          )
        end

        def update_summary(summary, labels: {})
          value = nil

          summary.observe(measure_time { value = yield }, labels:)

          value
        end

        def measure_time(unit = :float_millisecond)
          start_at = Process.clock_gettime(Process::CLOCK_MONOTONIC, unit)
          yield
          Process.clock_gettime(Process::CLOCK_MONOTONIC, unit) - start_at
        end
      end
  end
end
