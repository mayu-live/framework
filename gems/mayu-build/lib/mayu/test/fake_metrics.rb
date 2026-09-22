# frozen_string_literal: true

module Mayu
  module Test
    class FakeMetrics
      NullCounter = Data.define { def increment(**) = nil }
      NullSummary = Data.define { def observe(_value = nil, **) = nil }

      def active_sessions = NullCounter.new
      def session_starts_total = NullCounter.new
      def session_timeouts_total = NullCounter.new
      def session_pings_total = NullCounter.new
      def callback_events_total = NullCounter.new
      def navigations_total = NullCounter.new
      def component_mounts_total = NullCounter.new
      def component_reconcile_duration_ms = NullSummary.new
      def component_render_duration_ms = NullSummary.new
      def replace_children_ids_total = NullCounter.new
      def reconcile_continuations_total = NullCounter.new

      def update_summary(_summary, labels: {})
        yield
      end
    end
  end
end
