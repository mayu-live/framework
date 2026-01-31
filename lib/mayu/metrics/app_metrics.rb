# frozen_string_literal: true
#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

module Mayu
  module Metrics
    AppMetrics =
      Data.define(
        :session_count,
        :session_init_count,
        :session_timeout_count,
        :session_ping_count,
        :session_callback_count,
        :session_navigate_count,
        :component_mount_count,
        :component_patch_times,
        :component_children_update_times,
        :update_child_id_count,
        :update_chunk_count,
        :error_count
      ) do
        def self.setup(registry, **preset_labels)
          new(
            session_count:
              registry.gauge(
                :mayu_session_count,
                docstring: "Number of active sessions",
                labels: [*preset_labels.keys],
                preset_labels:
              ),
            session_init_count:
              registry.counter(
                :mayu_session_init_count,
                docstring: "Total number of sessions created",
                labels: [*preset_labels.keys],
                preset_labels:
              ),
            session_timeout_count:
              registry.counter(
                :mayu_session_timeout_count,
                docstring: "Total number of sessions timed out",
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
                labels: [:component, :method, *preset_labels.keys],
                preset_labels:
              ),
            session_navigate_count:
              registry.counter(
                :mayu_session_navigate_count,
                docstring: "Total number of navigates",
                labels: [:path, *preset_labels.keys],
                preset_labels:
              ),
            error_count:
              registry.counter(
                :mayu_error_count,
                docstring: "Total number errors",
                labels: [*preset_labels.keys],
                preset_labels:
              ),
            component_mount_count:
              registry.counter(
                :mayu_component_mount_times,
                docstring: "Component mount count",
                labels: [:component, *preset_labels.keys],
                preset_labels:
              ),
            component_children_update_times:
              registry.summary(
                :mayu_component_children_update_times,
                docstring: "Component patch times",
                labels: [:component, *preset_labels.keys],
                preset_labels:
              ),
            component_patch_times:
              registry.summary(
                :mayu_component_patch_times,
                docstring: "Component patch times",
                labels: [:component, *preset_labels.keys],
                preset_labels:
              ),
            update_child_id_count:
              registry.counter(
                :mayu_update_child_id_count,
                docstring: "Number of child IDs updated",
                labels: [:tag_name, *preset_labels.keys],
                preset_labels:
              ),
            update_chunk_count:
              registry.counter(
                :mayu_update_chunk_count,
                docstring: "Number of chunked child update resumes",
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
