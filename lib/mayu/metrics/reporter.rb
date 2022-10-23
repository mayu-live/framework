# typed: strict

module Mayu
  module Metrics
    module Reporter
      extend T::Sig

      sig do
        type_parameters(:M)
          .params(
            collector_endpoint: Async::IO::UNIXEndpoint,
            block:
              T
                .proc
                .params(arg0: Prometheus::Client::Registry)
                .returns(T.type_parameter(:M))
          )
          .returns(T.type_parameter(:M))
      end
      def self.run(collector_endpoint, &block)
        data_store = DataStore.new
        Prometheus::Client.config.data_store = data_store
        metrics = yield(Prometheus::Client::Registry.new)
        Client.connect_and_sync(collector_endpoint:, data_store:, interval: 1)
        metrics
      end

      class Client
        extend T::Sig

        sig do
          params(
            collector_endpoint: Async::IO::UNIXEndpoint,
            block: T.proc.params(arg0: Client).void
          ).void
        end
        def self.connect(collector_endpoint, &block)
          Console.logger.info(self, "Connecting to #{collector_endpoint.to_s}")
          collector_endpoint.connect { |peer| yield new(peer) }
        end

        sig do
          params(
            collector_endpoint: Async::IO::UNIXEndpoint,
            data_store: DataStore,
            interval: Integer,
            task: Async::Task
          ).returns(Async::Task)
        end
        def self.connect_and_sync(
          collector_endpoint:,
          data_store:,
          interval: 1,
          task: Async::Task.current
        )
          task.async do
            connect(collector_endpoint) do |client|
              loop do
                client.sync(data_store)
                sleep(interval)
              end
            end
          rescue Errno::EPIPE
            Console.logger.error(self, "Broken pipe")
          rescue Errno::ECONNREFUSED
            Console.logger.error(self, "Connection refused")
          end
        end

        sig { params(peer: Async::IO::Peer).void }
        def initialize(peer)
          wrapper = Wrapper.new
          @packer = T.let(wrapper.packer(peer), MessagePack::Packer)
        end

        sig { params(data_store: DataStore, task: Async::Task).void }
        def sync(data_store, task: Async::Task.current)
          send(:store, data_store.store)
        end

        private

        sig { params(args: T.untyped).void }
        def send(*args)
          @packer.write(args)
          @packer.flush
        end
      end

      class DataStore
        class MetricStore
          extend T::Sig

          sig do
            params(
              store: ValueHash,
              metric_name: Symbol,
              metric_type: Symbol,
              metric_settings: T::Hash[Symbol, T.untyped]
            ).void
          end
          def initialize(store, metric_name:, metric_type:, metric_settings:)
            @store = store
            @metric_name = metric_name
            @semaphore = T.let(Async::Semaphore.new, Async::Semaphore)
          end

          sig do
            type_parameters(:T)
              .params(block: T.proc.returns(T.type_parameter(:T)))
              .returns(T.type_parameter(:T))
          end
          def synchronize(&block)
            @semaphore.async { yield }.wait
          end

          sig do
            params(
              val: T.any(Integer, Float),
              labels: T::Hash[Symbol, T.untyped]
            ).void
          end
          def set(val:, labels: {})
            @store.store(labels, val.to_f)
          end

          sig do
            params(
              by: T.any(Integer, Float),
              labels: T::Hash[Symbol, T.untyped]
            ).void
          end
          def increment(by: 1, labels: {})
            @store.store(labels, @store.fetch(labels, 0.0) + by.to_f)
          end

          sig { params(labels: T::Hash[Symbol, T.untyped]).void }
          def get(labels:)
            @store.fetch(labels)
          end
        end

        extend T::Sig

        sig { returns(MetricHash) }
        attr_reader :store

        sig { void }
        def initialize
          @store = T.let(init_metric_hash, MetricHash)
        end

        sig do
          params(
            metric_name: Symbol,
            metric_type: Symbol,
            metric_settings: T::Hash[Symbol, T.untyped]
          ).returns(MetricStore)
        end
        def for_metric(metric_name, metric_type:, metric_settings: {})
          MetricStore.new(
            T.must(@store[metric_name]),
            metric_name:,
            metric_type:,
            metric_settings:
          )
        end

        private

        sig { returns(MetricHash) }
        def init_metric_hash
          Hash.new { |hash, metric_name| hash[metric_name] = init_value_hash }
        end

        sig { returns(ValueHash) }
        def init_value_hash
          Hash.new { |hash, labels| hash[labels] = 0 }
        end
      end
    end
  end
end
