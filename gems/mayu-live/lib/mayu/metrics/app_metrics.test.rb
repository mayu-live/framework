#!/usr/bin/env ruby -rbundler/setup
# frozen_string_literal: true

require "minitest/autorun"
require "prometheus/client"

require_relative "app_metrics"

class Mayu::Metrics::AppMetricsTest < Minitest::Test
  def test_registers_metrics_named_for_the_operation_they_measure
    registry = Prometheus::Client::Registry.new

    Mayu::Metrics::AppMetrics.setup(registry)

    assert_equal(
      %i[
        mayu_active_sessions
        mayu_callback_events_total
        mayu_callback_handler_duration_milliseconds
        mayu_callback_queue_duration_milliseconds
        mayu_client_command_apply_batches_total
        mayu_client_command_apply_commands_total
        mayu_client_command_apply_duration_milliseconds_total
        mayu_command_batch_commands_total
        mayu_command_batch_compressed_bytes_total
        mayu_command_batch_uncompressed_bytes_total
        mayu_command_batches_total
        mayu_component_mounts_total
        mayu_component_reconcile_duration_milliseconds
        mayu_component_render_duration_milliseconds
        mayu_navigations_total
        mayu_reconcile_continuations_total
        mayu_replace_children_ids_total
        mayu_session_pings_total
        mayu_session_starts_total
        mayu_session_timeouts_total
      ],
      registry.metrics.map(&:name).sort
    )
  end
end
