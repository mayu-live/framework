#!/usr/bin/env -S ruby -rbundler/setup
# frozen_string_literal: true

require "async"
require "vernier"

require_relative "../../../test"
require_relative "../../engine"
require_relative "../collector"
require_relative "../vdocument"

module Mayu
  module Runtime
    module VNodes
      class UpdateProfile
        H = Mayu::Runtime::H
        NullMetrics = Mayu::Test::FakeMetrics

        # ITERATIONS = Integer(ENV.fetch("MAYU_PROFILE_ITERATIONS", "5000"))
        ITERATIONS = Integer(ENV.fetch("MAYU_PROFILE_ITERATIONS", "100"))
        WARMUP = Integer(ENV.fetch("MAYU_PROFILE_WARMUP", "200"))

        START_OF_LINE_AND_CLEAR = "\r\e[2K"

        class UpdateTraceHook
          @collector = nil

          FIREFOX_MARKER_SCHEMA = [
            {
              name: "mayu.vnodes.update",
              display: %w[marker-chart marker-table timeline-overview],
              tooltipLabel: "{marker.data.label}",
              chartLabel: "{marker.data.label}",
              tableLabel: "{marker.data.label}",
              data: [
                {key: "label", format: "string", searchable: true},
                {key: "iteration", format: "integer"}
              ]
            }
          ].freeze

          class << self
            attr_accessor :collector
          end

          def initialize(collector)
            @collector = collector
          end

          def enable
            self.class.collector = @collector
          end

          def disable
            self.class.collector = nil
          end

          def self.trace_update(index)
            collector = self.collector
            return yield unless collector

            collector.record_interval(
              "mayu.vnodes.update",
              "Update #{index}"
            ) { yield }
          end

          def firefox_marker_schema
            FIREFOX_MARKER_SCHEMA
          end
        end

        class UpdateProbe < Mayu::Component::Base
          ROWS = 32
          COLS = 16

          def initialize
            @tick = 0
          end

          def advance!
            @tick += 1
            rerender!
          end

          def render
            H[
              :main,
              *ROWS.times.map { |row| render_row(row) },
              class: ["phase-#{@tick % 2}"],
              data: {
                tick: @tick
              }
            ]
          end

          private

          def render_row(row)
            H[
              :section,
              H[:h2, "Row #{row}"],
              H[
                :ul,
                *COLS.times.map do |col|
                  value = (row + col + @tick) % 8
                  H[
                    :li,
                    "cell #{row}:#{col}:#{@tick % 3}",
                    class: ["cell", "v-#{value}"],
                    data: {
                      row: row,
                      col: col,
                      value: value
                    }
                  ]
                end
              ],
              class: ["row", ("active" if ((row + @tick) % 4).zero?)].compact
            ]
          end
        end

        def self.run
          descriptor = H[:body, H[UpdateProbe]]
          engine =
            Mayu::Runtime::Engine.new(descriptor, metrics: NullMetrics.new)

          Async do
            engine.start

            root = engine.root
            component = find_component(root, UpdateProbe)
            instance = component.instance_variable_get(:@instance)

            drain_queue(engine)

            puts "Warming up..."

            WARMUP.times do
              print_progress(it, WARMUP)
              tick(engine, instance)
            end

            puts

            filename = File.join(Bundler.root, "mayu-vnode-update.json")

            # out = +""
            # root.write_html(out)
            # puts out

            puts "Profiling..."

            result =
              Vernier.profile(
                name: "mayu-vnode-update",
                out: filename,
                hooks: [UpdateTraceHook]
              ) do
                ITERATIONS.times do
                  print_progress(it, ITERATIONS)
                  tick(engine, instance, it)
                end
              end

            clear_print "Done\n"

            puts format(
              "Profile complete: %f seconds, %d threads, %d samples, %d unique",
              result.elapsed_seconds,
              result.threads.count,
              result.total_samples,
              result.total_unique_samples
            )

            puts
            puts "Profile written to \e[33m#{filename}\e[0m"
            puts "Upload the output to \e[34mhttps://profiler.firefox.com/\e[0m"
          ensure
            engine.stop
          end.wait
        end

        def self.print_progress(current, total)
          clear_print format("%3.2f%%", current / total.to_f * 100.0)
        end

        def self.clear_print(str)
          $stdout.print "#{START_OF_LINE_AND_CLEAR}#{str}"
          $stdout.flush
        end

        def self.tick(engine, instance, index = nil)
          UpdateTraceHook.trace_update(index) do
            instance.advance!
            Async::Task.current.with_timeout(1.0) { engine.dequeue_batch }
          end
        end

        def self.drain_queue(engine)
          loop do
            Async::Task.current.with_timeout(0.01) { engine.dequeue_batch }
          end
        rescue Async::TimeoutError
          nil
        end

        def self.find_component(node, klass)
          if node.is_a?(Mayu::Runtime::VNodes::VComponent)
            instance = node.instance_variable_get(:@instance)
            return node if instance.is_a?(klass)
          end

          case node
          when Mayu::Runtime::VNodes::VDocument
            find_component(node.instance_variable_get(:@html), klass)
          when Mayu::Runtime::VNodes::VAny
            find_component(node.instance_variable_get(:@child), klass)
          when Mayu::Runtime::VNodes::VComponent
            find_component(node.instance_variable_get(:@children), klass)
          when Mayu::Runtime::VNodes::VElement
            find_component(node.instance_variable_get(:@children), klass)
          when Mayu::Runtime::VNodes::VCustomElement
            find_component(node.instance_variable_get(:@element), klass)
          when Mayu::Runtime::VNodes::VSlot, Mayu::Runtime::VNodes::VStateless
            find_component(node.instance_variable_get(:@children), klass)
          when Mayu::Runtime::VNodes::VChildren
            node
              .instance_variable_get(:@children)
              .each do |child|
                found = find_component(child, klass)
                return found if found
              end

            nil
          end
        end
      end
    end
  end
end

Mayu::Runtime::VNodes::UpdateProfile.run
