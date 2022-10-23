# typed: strict

require "bundler/setup"
require "async"
require "async/container"
require "async/semaphore"
require "async/http"
require "async/io/unix_endpoint"
require "async/io/shared_endpoint"
require "msgpack"
require "nanoid"
require "prometheus/client"
require "prometheus/client/formats/text"

require_relative "metrics/collector"
require_relative "metrics/exporter"
require_relative "metrics/reporter"

module Mayu
  module Metrics
    InternalStore = T.type_alias { T::Hash[Symbol, MetricHash] }
    MetricHash = T.type_alias { T::Hash[Symbol, ValueHash] }
    ValueHash = T.type_alias { T::Hash[LabelsHash, Float] }
    LabelsHash = T.type_alias { T::Hash[Symbol, T.untyped] }

    class Wrapper < MessagePack::Factory
      extend T::Sig

      sig { void }
      def initialize
        super()

        self.register_type(0x01, Symbol)
      end
    end

    extend T::Sig

    sig do
      params(
        container: Async::Container::Generic,
        exporter_endpoint: Async::HTTP::Endpoint,
        collector_endpoint: Async::IO::UNIXEndpoint,
        block: T.proc.params(arg0: Prometheus::Client::Registry).void
      ).void
    end
    def self.start_collect_and_export(
      container,
      exporter_endpoint:,
      collector_endpoint:,
      &block
    )
      collector = Metrics::Collector::Server.new(collector_endpoint)
      collector.start

      container.spawn(name: "Metrics collector/exporter") do |instance|
        Async do
          internal_store = {}

          Prometheus::Client.config.data_store =
            Metrics::Collector::DataStore.new(internal_store)

          registry = Prometheus::Client::Registry.new

          yield registry

          Metrics::Exporter::Server.setup(
            endpoint: exporter_endpoint,
            registry:
          ).run

          collector.run(internal_store)

          instance.ready!
        end
      end
    end
  end
end
