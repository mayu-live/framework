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
      # A dashboard-style reconciliation benchmark. Unlike the cellular update
      # benchmark, this keeps most row components stable while repeatedly
      # editing, inserting, deleting, and moving keyed rows.
      class ReconciliationProfile
        H = Mayu::Runtime::H
        NullMetrics = Mayu::Test::FakeMetrics

        ITERATIONS = Integer(ENV.fetch("MAYU_PROFILE_ITERATIONS", "200"))
        WARMUP = Integer(ENV.fetch("MAYU_PROFILE_WARMUP", "50"))
        SHOW_PROGRESS = ENV.fetch("MAYU_PROFILE_PROGRESS", "1") != "0"
        PROFILE = ENV.fetch("MAYU_PROFILE", "1") != "0"
        RECORD_COUNT = Integer(ENV.fetch("MAYU_RECONCILIATION_RECORDS", "240"))
        MUTATION_COUNT = Integer(ENV.fetch("MAYU_RECONCILIATION_MUTATIONS", "16"))

        START_OF_LINE_AND_CLEAR = "\r\e[2K"

        class UpdateTraceHook
          @collector = nil

          FIREFOX_MARKER_SCHEMA = [
            {
              name: "mayu.vnodes.reconciliation_update",
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
              "mayu.vnodes.reconciliation_update",
              "#{operation} #{index}"
            ) { yield }
          end

          def firefox_marker_schema
            FIREFOX_MARKER_SCHEMA
          end
        end

        Record = Data.define(
          :id,
          :title,
          :status,
          :priority,
          :owner,
          :tags,
          :description
        )

        class RecordRow < Mayu::Component::Base
          def should_update?(next_props)
            @__props[:record] != next_props[:record] ||
              @__props[:selected] != next_props[:selected]
          end

          def render
            record = @__props[:record]
            selected = @__props[:selected]

            H[
              :article,
              H[
                :header,
                H[:h3, record.title],
                H[
                  :span,
                  record.status,
                  class: ["status", "status-#{record.status}"]
                ]
              ],
              H[:p, record.description],
              H[
                :footer,
                H[:span, "#{record.owner} · P#{record.priority}"],
                H[:ul, *record.tags.map { H[:li, it, key: it] }]
              ],
              class: ["record", ("selected" if selected)],
              data: {record_id: record.id, priority: record.priority},
              onclick: @__props[:onselect]
            ]
          end
        end

        class Dashboard < Mayu::Component::Base
          STATIC_SIDEBAR =
            H[
              :aside,
              H[:h2, "Workspace"],
              H[:nav, H[:a, "Overview"], H[:a, "Projects"], H[:a, "Reports"]]
            ]

          def initialize
            @tick = 0
            @next_id = RECORD_COUNT
            @selected_id = 0
            @operation = :edit
            @records = Array.new(RECORD_COUNT) { build_record(it) }
          end

          attr_reader :operation

          def advance!
            @tick += 1
            @operation = %i[edit insert reorder delete].fetch(@tick % 4)

            case @operation
            when :edit then edit_records
            when :insert then insert_records
            when :reorder then reorder_records
            when :delete then delete_records
            end

            rerender!
          end

          def select_record(_event)
          end

          def render
            H[
              :main,
              STATIC_SIDEBAR,
              H[
                :section,
                H[
                  :header,
                  H[:h1, "Project records"],
                  H[:output, "#{@records.length} records"],
                  H[:span, @operation.to_s, class: "operation"]
                ],
                H[
                  :div,
                  *@records.map do |record|
                    H[
                      RecordRow,
                      key: record.id,
                      record:,
                      selected: record.id == @selected_id,
                      onselect: H.callback(self, :select_record)
                    ]
                  end,
                  class: "record-list"
                ],
                class: "content",
                data: {operation: @operation, tick: @tick}
              ]
            ]
          end

          private

          def build_record(id)
            status = %w[active review blocked].fetch(id % 3)
            Record[
              id,
              "Record #{id}",
              status,
              (id % 4) + 1,
              "Owner #{id % 12}",
              ["team-#{id % 6}", "area-#{id % 9}"],
              "A detailed description for record #{id}."
            ]
          end

          def edit_records
            records = @records.dup
            MUTATION_COUNT.times do |offset|
              index = (@tick * 17 + offset * 29) % records.length
              record = records.fetch(index)
              status = %w[active review blocked].fetch((@tick + offset) % 3)
              records[index] =
                record.with(
                  status:,
                  priority: ((record.priority + @tick + offset) % 4) + 1,
                  description: "Updated at revision #{@tick}."
                )
            end
            @selected_id = records.fetch(@tick % records.length).id
            @records = records
          end

          def insert_records
            records = @records.dup
            inserted = Array.new(MUTATION_COUNT) { build_record(next_id) }
            insertion_index = (@tick * 37) % (records.length + 1)
            records.insert(insertion_index, *inserted)
            @records = records
          end

          def reorder_records
            records = @records.dup
            from = (@tick * 19) % (records.length - MUTATION_COUNT)
            moved = records.slice!(from, MUTATION_COUNT)
            to = (@tick * 47) % (records.length + 1)
            records.insert(to, *moved)
            @records = records
          end

          def delete_records
            records = @records.dup
            from = (@tick * 23) % (records.length - MUTATION_COUNT)
            records.slice!(from, MUTATION_COUNT)
            @selected_id = records.first.id unless records.any? { it.id == @selected_id }
            @records = records
          end

          def next_id
            id = @next_id
            @next_id += 1
            id
          end
        end

        def self.run
          engine =
            Mayu::Runtime::Engine.new(
              H[:body, H[Dashboard]],
              metrics: NullMetrics.new,
              # Each iteration represents one complete application update.
              update_budget: Float::INFINITY
            )

          Async do
            engine.start
            dashboard = find_component(engine.root, Dashboard)
            instance = dashboard.instance_variable_get(:@instance)
            drain_queue(engine)

            puts "Warming up #{RECORD_COUNT} keyed records..."
            WARMUP.times { tick(engine, instance, it) }

            filename = File.join(Bundler.root, "mayu-vnode-reconciliation.json")
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
              write_result("reconciliation", measurement, cpu_ms_per_update)
              next
            end

            result =
              Vernier.profile(
                name: "mayu-vnode-reconciliation",
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
            Async::Task.current.with_timeout(5.0) { engine.dequeue_batch }
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

Mayu::Runtime::VNodes::ReconciliationProfile.run
