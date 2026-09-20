# frozen_string_literal: true

module Mayu
  module Test
    class FakeMetrics
      NullCounter = Data.define { def increment(**) = nil }
      NullSummary = Data.define { def observe(_value = nil, **) = nil }

      def component_mount_count = NullCounter.new
      def component_children_update_times = NullSummary.new
      def component_patch_times = NullSummary.new
      def update_child_id_count = NullCounter.new
      def update_chunk_count = NullCounter.new
      def session_callback_count = NullCounter.new
      def session_ping_count = NullCounter.new

      def update_summary(_summary, labels: {})
        yield
      end
    end
  end
end
