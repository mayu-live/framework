# frozen_string_literal: true

# Copyright Andrés Alin <andreas.alin@gmail.com>
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

require "delegate"

module Mayu
  module Devtools
    # Keeps a session's render and callback timings for the devtools. It
    # wraps the engine's metrics, which the runtime already times these
    # with, and passes every call on, so Prometheus sees the same as before.
    class Recorder < SimpleDelegator
      Timing =
        Struct.new(:count, :total_ms, :max_ms, :last_ms) do
          def self.empty = new(0, 0.0, 0.0, 0.0)

          def add(ms)
            self.count += 1
            self.total_ms += ms
            self.max_ms = ms if ms > max_ms
            self.last_ms = ms
          end
        end

      # A summary tagged with what it measures. Summaries can't be told
      # apart by identity: a test's fake metrics make a new one per call.
      class Tagged < SimpleDelegator
        attr_reader :kind

        def initialize(kind, summary)
          super(summary)
          @kind = kind
        end
      end

      # Wraps the engine's metrics, once. Recording starts here, so timings
      # cover what happened since the devtools first asked.
      def self.install(engine)
        engine.metrics = new(engine.metrics) unless engine.metrics.is_a?(self)
        engine.metrics
      end

      # Timings by kind (:render, :reconcile, :callback), each keyed by the
      # component label, or the component label and method for callbacks.
      attr_reader :timings
      attr_reader :started_at

      def initialize(metrics)
        super
        reset
      end

      def reset
        @timings = Hash.new { |kinds, kind| kinds[kind] = Hash.new { |timings, key| timings[key] = Timing.empty } }
        @started_at = Process.clock_gettime(Process::CLOCK_REALTIME, :millisecond)
      end

      def component_render_duration_ms = Tagged.new(:render, super)

      def component_reconcile_duration_ms = Tagged.new(:reconcile, super)

      def callback_handler_duration_ms = Tagged.new(:callback, super)

      def update_summary(summary, labels: {}, &)
        return super unless summary.is_a?(Tagged)

        started = clock
        begin
          super(summary.__getobj__, labels:, &)
        ensure
          key = (summary.kind == :callback) ? [labels[:component], labels[:method]] : labels[:component]
          @timings[summary.kind][key].add(clock - started)
        end
      end

      private

      def clock = Process.clock_gettime(Process::CLOCK_MONOTONIC, :float_millisecond)
    end
  end
end
