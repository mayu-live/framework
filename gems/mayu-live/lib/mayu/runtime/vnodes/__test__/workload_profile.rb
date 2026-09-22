#!/usr/bin/env -S ruby -rbundler/setup
# frozen_string_literal: true

require "async"
require "benchmark"
require "json"
require "vernier"

require "mayu/test"
require_relative "../../engine"
require_relative "../command_collector"
require_relative "../vdocument"

module Mayu
  module Runtime
    module VNodes
      # Profiles rendering workloads that complement the keyed reconciliation
      # benchmark. Select one with MAYU_WORKLOAD=attributes or =subtree.
      class WorkloadProfile
        H = Mayu::Runtime::H
        NullMetrics = Mayu::Test::FakeMetrics

        ITERATIONS = Integer(ENV.fetch("MAYU_PROFILE_ITERATIONS", "200"))
        WARMUP = Integer(ENV.fetch("MAYU_PROFILE_WARMUP", "50"))
        PROFILE = ENV.fetch("MAYU_PROFILE", "1") != "0"
        WORKLOAD = ENV.fetch("MAYU_WORKLOAD", "attributes")

        class UpdateTraceHook
          @collector = nil

          FIREFOX_MARKER_SCHEMA = [
            {
              name: "mayu.vnodes.workload_update",
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

          def self.trace_update(index, operation)
            collector = self.collector
            return yield unless collector

            collector.record_interval(
              "mayu.vnodes.workload_update",
              "#{operation} #{index}"
            ) { yield }
          end

          def firefox_marker_schema
            FIREFOX_MARKER_SCHEMA
          end
        end

        # A form with stable event callbacks and many fresh descriptors on
        # every render. Each update changes only a subset of values, validity
        # classes, inline styles, data attributes, and accessibility state.
        class AttributesForm < Mayu::Component::Base
          FIELD_COUNT = Integer(ENV.fetch("MAYU_ATTRIBUTE_FIELDS", "240"))
          MUTATION_COUNT = Integer(ENV.fetch("MAYU_ATTRIBUTE_MUTATIONS", "40"))

          attr_reader :operation

          def initialize
            @tick = 0
            @operation = :value
            @values = Array.new(FIELD_COUNT) { "Value #{it}" }
            @revisions = Array.new(FIELD_COUNT, 0)
            @invalid = Array.new(FIELD_COUNT, false)
            @disabled = Array.new(FIELD_COUNT, false)
          end

          def advance!
            @tick += 1
            @operation = %i[value validation layout].fetch(@tick % 3)

            MUTATION_COUNT.times do |offset|
              index = (@tick * 31 + offset * 17) % FIELD_COUNT
              @revisions[index] += 1

              case @operation
              when :value
                @values[index] = "Value #{index} revision #{@revisions[index]}"
              when :validation
                @invalid[index] = !@invalid[index]
              when :layout
                @disabled[index] = !@disabled[index]
              end
            end

            rerender!
          end

          def change(_event)
          end

          def render
            H[
              :main,
              H[:h1, "Account settings"],
              H[:output, "#{@operation} #{@tick}"],
              H[
                :form,
                *FIELD_COUNT.times.map { render_field(it) },
                class: ["settings-form", "phase-#{@operation}"],
                data: {revision: @tick, operation: @operation}
              ]
            ]
          end

          private

          def render_field(index)
            invalid = @invalid[index]
            revision = @revisions[index]

            H[
              :input,
              key: index,
              value: @values[index],
              disabled: @disabled[index],
              class: ["field", ("invalid" if invalid), "r-#{revision % 4}"],
              style: {width: "#{20 + (revision % 8)}ch", opacity: invalid ? 0.7 : 1},
              data: {field: index, revision:},
              aria: {invalid:, describedby: "field-help-#{index}"},
              oninput: H.callback(self, :change)
            ]
          end
        end

        # Replaces a large branch with a different root shape, then removes
        # it. This exercises vnode construction, HTML/ID-tree creation,
        # CreateTree/RemoveNode generation, and the parent ReplaceChildren.
        class SubtreeSwitcher < Mayu::Component::Base
          CARD_COUNT = Integer(ENV.fetch("MAYU_SUBTREE_CARDS", "160"))

          attr_reader :operation

          def initialize
            @tick = 0
            @operation = :summary
          end

          def advance!
            @tick += 1
            @operation = %i[summary activity hidden].fetch(@tick % 3)
            rerender!
          end

          def render
            H[
              :main,
              H[:header, H[:h1, "Project workspace"], H[:output, @operation]],
              render_subtree
            ]
          end

          private

          def render_subtree
            case @operation
            when :summary then summary_tree
            when :activity then activity_tree
            end
          end

          def summary_tree
            H[
              :section,
              H[:h2, "Summary"],
              H[:div, *CARD_COUNT.times.map { summary_card(it) }, class: "cards"],
              key: :content
            ]
          end

          def activity_tree
            H[
              :aside,
              H[:h2, "Activity"],
              H[:ol, *CARD_COUNT.times.map { activity_card(it) }, class: "activity"],
              key: :content
            ]
          end

          def summary_card(index)
            H[
              :article,
              H[:header, H[:h3, "Card #{index}"], H[:span, "P#{index % 4}"]],
              H[:p, "A detailed summary for card #{index}."],
              H[:footer, H[:span, "Owner #{index % 12}"], H[:time, (index + @tick).to_s]],
              class: ["card", "state-#{index % 3}"],
              data: {card: index, revision: @tick}
            ]
          end

          def activity_card(index)
            H[
              :li,
              H[:article, H[:h3, "Event #{index}"], H[:p, "Activity at #{@tick}."], H[:time, "#{index}:#{@tick}"]],
              class: ["activity-item", "kind-#{index % 5}"],
              data: {event: index, revision: @tick}
            ]
          end
        end

        WORKLOADS = {"attributes" => AttributesForm, "subtree" => SubtreeSwitcher}.freeze

        def self.run
          component_class = WORKLOADS.fetch(WORKLOAD) do
            raise ArgumentError, "Unknown MAYU_WORKLOAD=#{WORKLOAD.inspect}; expected #{WORKLOADS.keys.join(", ")}"
          end
          engine =
            Mayu::Runtime::Engine.new(
              H[:body, H[component_class]],
              metrics: NullMetrics.new,
              update_budget: Float::INFINITY
            )

          Async do
            engine.start
            component = find_component(engine.root, component_class)
            instance = component.instance_variable_get(:@instance)
            drain_queue(engine)

            puts "Warming up #{WORKLOAD}..."
            WARMUP.times { tick(engine, instance, it) }

            filename = File.join(Bundler.root, "mayu-vnode-#{WORKLOAD}.json")
            puts(PROFILE ? "Profiling..." : "Benchmarking...")
            run = proc { ITERATIONS.times { tick(engine, instance, it) } }

            unless PROFILE
              measurement = Benchmark.measure(&run)
              cpu_ms_per_update = measurement.total * 1000 / ITERATIONS
              puts format(
                "Done: %.6f wall, %.6f CPU seconds; %.3f CPU ms/update",
                measurement.real,
                measurement.total,
                cpu_ms_per_update
              )
              write_result(WORKLOAD, measurement, cpu_ms_per_update)
              next
            end

            result =
              Vernier.profile(
                name: "mayu-vnode-#{WORKLOAD}",
                out: filename,
                hooks: [UpdateTraceHook],
                &run
              )

            puts format(
              "Profile complete: %f seconds, %d threads, %d samples, %d unique",
              result.elapsed_seconds,
              result.threads.count,
              result.total_samples,
              result.total_unique_samples
            )
            puts "Profile written to #{filename}"
            puts "Upload the output to https://profiler.firefox.com/"
          ensure
            engine.stop
          end.wait
        end

        def self.tick(engine, instance, index)
          instance.advance!
          UpdateTraceHook.trace_update(index, instance.operation) do
            Async::Task.current.with_timeout(10.0) { engine.dequeue_batch }
          end
        end

        def self.write_result(workload, measurement, cpu_ms_per_update)
          filename = ENV["MAYU_PROFILE_RESULT"]
          return unless filename

          File.write(
            filename,
            JSON.pretty_generate(
              workload:,
              iterations: ITERATIONS,
              warmup: WARMUP,
              wall_seconds: measurement.real,
              cpu_seconds: measurement.total,
              cpu_ms_per_update:
            )
          )
        end

        def self.drain_queue(engine)
          loop do
            Async::Task.current.with_timeout(0.01) { engine.dequeue_batch }
          end
        rescue Async::TimeoutError
          nil
        end

        def self.find_component(root, klass)
          root.send(:traverse) do |node|
            next unless node.is_a?(VComponent)
            instance = node.instance_variable_get(:@instance)
            return node if instance.is_a?(klass)
          end
        end
      end
    end
  end
end

Mayu::Runtime::VNodes::WorkloadProfile.run
