# frozen_string_literal: true
#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "monitor"
require "async"

module Mayu
  module Metrics
    module Reporter
      Session =
        Data.define(:metrics, :sync_task) do
          def stop
            sync_task&.stop
          end
        end

      def self.run(
        collector_endpoint,
        task: Async::Task.current,
        &setup_metrics
      )
        data_store = DataStore.new

        Prometheus::Client.config.data_store = data_store

        metrics = setup_metrics.call(Prometheus::Client::Registry.new)
        sync_task =
          Client.connect_and_sync(collector_endpoint:, data_store:, task:)

        Session[metrics:, sync_task:]
      end

      class Client
        def self.connect(collector_endpoint, &block)
          Console.logger.debug(
            self,
            "Connecting to #{File.expand_path(collector_endpoint.path)}"
          )

          collector_endpoint.connect { |peer| block.call(new(peer)) }
        end

        def self.connect_and_sync(
          collector_endpoint:,
          data_store:,
          interval: 1,
          reconnect_delay: 0.25,
          task: Async::Task.current
        )
          task.async do
            loop do
              begin
                connect(collector_endpoint) do |client|
                  loop do
                    client.sync(data_store)
                    sleep(interval)
                  end
                end
              rescue Errno::ECONNREFUSED, Errno::EPIPE, Errno::ENOENT => error
                break if task.stopped?
                Console.logger.warn(self, "Metrics sync error: #{error.class}")
                sleep(reconnect_delay)
              rescue Interrupt, Async::Stop
                break
              end
            end
          end
        end

        def initialize(peer)
          wrapper = Wrapper.new
          @packer = wrapper.packer(peer)
        end

        def sync(data_store)
          send(:store, data_store.snapshot)
        end

        private

        def send(*args)
          @packer.write(args)
          @packer.flush
        end
      end

      class DataStore
        class MetricStore
          def initialize(
            value_store,
            lock,
            metric_name:,
            metric_type:,
            metric_settings:
          )
            @value_store = value_store
            @lock = lock
            @metric_name = metric_name
            @metric_type = metric_type
            @metric_settings = metric_settings
          end

          def synchronize
            @lock.synchronize { yield }
          end

          def set(labels:, val:)
            synchronize { @value_store[label_key(labels)] = val.to_f }
          end

          def increment(labels:, by: 1)
            synchronize { @value_store[label_key(labels)] += by.to_f }
          end

          def get(labels:)
            synchronize { @value_store.fetch(label_key(labels), 0.0) }
          end

          def all_values
            synchronize { @value_store.dup }
          end

          private

          def label_key(labels)
            labels.frozen? ? labels : labels.dup.freeze
          end
        end

        def initialize
          @store =
            Hash.new do |hash, metric_name|
              hash[metric_name] = init_value_store
            end
          @lock = Monitor.new
        end

        def for_metric(metric_name, metric_type:, metric_settings: {})
          MetricStore.new(
            @store[metric_name],
            @lock,
            metric_name:,
            metric_type:,
            metric_settings:
          )
        end

        def snapshot
          @lock.synchronize do
            @store.each_with_object(
              {}
            ) do |(metric_name, value_store), snapshot|
              snapshot[metric_name] = value_store.dup
            end
          end
        end

        private

        def init_value_store
          Hash.new(0.0)
        end
      end
    end
  end
end
