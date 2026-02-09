# frozen_string_literal: true
#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "prometheus/client"
require "msgpack"
require "io/endpoint"
require "io/endpoint/unix_endpoint"
require_relative "metrics/app_metrics"
require_relative "metrics/collector"
require_relative "metrics/reporter"
require_relative "metrics/server"

module Mayu
  module Metrics
    class Wrapper < MessagePack::Factory
      def initialize
        super()

        self.register_type(0x01, Symbol)
      end
    end

    def self.collector_endpoint(root)
      IO::Endpoint.unix(File.join(root, "metrics.ipc"))
    end

    def self.start_collect_and_export(
      container,
      collector_endpoint:,
      listen:,
      &setup_registry
    )
      container.run(name: "Mayu metrics", count: 1, restart: true) do |instance|
        collector = nil

        Async do |task|
          collector = Collector::Server.new(collector_endpoint)
          collector.start

          internal_store = {}
          Prometheus::Client.config.data_store =
            Collector::DataStore.new(internal_store)

          registry = Prometheus::Client::Registry.new
          setup_registry&.call(registry)

          metrics_server = Server.new(registry:, listen:)

          task.async { collector.run(internal_store) }
          task.async { metrics_server.run.wait }

          instance.ready!
          task.children.each(&:wait)
        ensure
          collector&.stop
        end
      end
    end
  end
end
