# typed: strict

module Mayu
  module Metrics
    module Collector
      class DataStore
        class MetricStore
          extend T::Sig

          sig { returns(DataStore) }
          attr_reader :store

          sig do
            params(
              store: DataStore,
              metric_name: Symbol,
              metric_type: Symbol,
              metric_settings: T::Hash[Symbol, T.untyped]
            ).void
          end
          def initialize(store, metric_name, metric_type:, metric_settings: {})
            @store = store
            @metric_name = metric_name
            @metric_type = metric_type
            @metric_settings = metric_settings
            @aggregation_mode =
              T.let(metric_settings.fetch(:aggregation, :sum), Symbol)
          end

          sig do
            params(
              val: T.any(Integer, Float),
              labels: T::Hash[Symbol, T.untyped]
            ).void
          end
          def set(val:, labels: {})
          end

          sig { returns(T::Hash[T::Array[Symbol], Float]) }
          def all_values
            @store
              .values_for_metric(@metric_name)
              .transform_values { aggregate(_1) }
          end

          private

          sig { params(values: T::Array[Float]).returns(Float) }
          def aggregate(values)
            case @aggregation_mode
            when :min
              values.min
            when :max
              values.max
            when :sum
              values.sum
            else
              raise "Invalid aggregation setting"
            end.to_f
          end
        end

        extend T::Sig

        sig { returns(InternalStore) }
        attr_reader :internal_store

        sig { params(internal_store: InternalStore).void }
        def initialize(internal_store = {})
          @internal_store = internal_store
        end

        sig do
          params(metric_name: Symbol).returns(
            T::Hash[T::Array[Symbol], T::Array[Float]]
          )
        end
        def values_for_metric(metric_name)
          @internal_store
            .values
            .map { _1[metric_name] }
            .compact
            .each_with_object(Hash.new { |h, k| h[k] = [] }) do |entries, obj|
              entries.each { |labels, value| obj[labels] << value }
            end
        end

        sig do
          params(
            metric_name: Symbol,
            metric_type: Symbol,
            metric_settings: T::Hash[Symbol, T.untyped]
          ).returns(MetricStore)
        end
        def for_metric(metric_name, metric_type:, metric_settings: {})
          MetricStore.new(self, metric_name, metric_type:, metric_settings: {})
        end
      end

      class Server
        extend T::Sig

        sig { returns(Async::IO::Endpoint) }
        attr_reader :endpoint

        sig { params(endpoint: Async::IO::UNIXEndpoint).void }
        def initialize(endpoint)
          @endpoint = endpoint
        end

        sig { params(metric_name: Symbol).void }
        def all_values(metric_name)
          raise NotImplementedError, "Should this even be implemented?"
        end

        sig { void }
        def start
        end

        sig { void }
        def stop
        end

        sig do
          params(
            internal_store: InternalStore,
            name: String,
            restart: T::Boolean
          ).void
        end
        def run(internal_store, name: self.class.name.to_s, restart: true)
          wrapper = Wrapper.new

          Console.logger.info(
            self,
            "Starting: #{File.expand_path(@endpoint.path)}"
          )

          @endpoint.accept do |peer|
            store = internal_store.store(peer, {})

            unpacker = wrapper.unpacker(peer)

            unpacker.each do |message|
              case message
              in [:store, data]
                store.merge!(data)
              else
                Console
                  .logger
                  .warn(self) { "Unhandled mesage: #{message.inspect}" }
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
