# frozen_string_literal: true
#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "fileutils"

module Mayu
  module Metrics
    module Collector
      class DataStore
        class MetricStore
          def initialize(store, metric_name, metric_type:, metric_settings: {})
            @store = store
            @metric_name = metric_name
            @metric_type = metric_type
            @aggregation =
              metric_settings.fetch(
                :aggregation,
                metric_settings.fetch("aggregation", :sum)
              ).to_sym
          end

          def synchronize
            yield
          end

          # Aggregated store is read-only from Prometheus perspective.
          def set(val:, labels: {})
          end

          # Aggregated store is read-only from Prometheus perspective.
          def increment(by: 1, labels: {})
          end

          def get(labels:)
            all_values.fetch(labels, 0.0)
          end

          def all_values
            @store
              .values_for_metric(@metric_name)
              .transform_values { |values| aggregate(values) }
          end

          private

          def aggregate(values)
            case @aggregation
            in :sum
              values.sum
            in :max
              values.max || 0.0
            in :min
              values.min || 0.0
            else
              raise "Invalid aggregation mode: #{@aggregation.inspect}"
            end.to_f
          end
        end

        def initialize(internal_store = {})
          @internal_store = internal_store
        end

        def values_for_metric(metric_name)
          @internal_store
            .values
            .map { _1[metric_name] }
            .compact
            .each_with_object(
              Hash.new { |hash, key| hash[key] = [] }
            ) do |metric_values, all_values|
              metric_values.each do |labels, value|
                all_values[labels] << value.to_f
              end
            end
        end

        def for_metric(metric_name, metric_type:, metric_settings: {})
          MetricStore.new(self, metric_name, metric_type:, metric_settings:)
        end
      end

      class Server
        def initialize(endpoint)
          @endpoint = endpoint
        end

        def start
          path = @endpoint.path

          FileUtils.mkdir_p(File.dirname(path))
          FileUtils.rm_f(path)
        end

        def stop
          FileUtils.rm_f(@endpoint.path)
        end

        def run(internal_store)
          wrapper = Wrapper.new

          Console.logger.info(
            self,
            "Starting metrics collection on #{File.expand_path(@endpoint.path)}"
          )

          @endpoint.accept do |peer|
            unpacker = wrapper.unpacker(peer)

            unpacker.each do |message|
              case message
              in [:store | "store", data]
                internal_store[peer] = data
              else
                Console.logger.warn(
                  self,
                  "Unhandled message: #{message.inspect}"
                )
              end
            end
          ensure
            internal_store.delete(peer)
          end
        end
      end
    end
  end
end
