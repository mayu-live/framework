# frozen_string_literal: true

#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "prometheus/client"
require "msgpack"
require "uri"
require "io/endpoint"
require "io/endpoint/unix_endpoint"
require_relative "metrics/app_metrics"
require_relative "metrics/collector"
require_relative "metrics/reporter"
require_relative "metrics/server"

module Mayu
  module Metrics
    MAX_PORT_BIND_ATTEMPTS = 100

    class Wrapper < MessagePack::Factory
      def initialize
        super

        register_type(0x01, Symbol)
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
        collector_task = nil
        metrics_task = nil
        internal_store = {}

        Async do |task|
          collector = Collector::Server.new(collector_endpoint)
          collector.start

          Prometheus::Client.config.data_store =
            Collector::DataStore.new(internal_store)

          registry = Prometheus::Client::Registry.new
          setup_registry&.call(registry)

          collector_task = task.async { collector.run(internal_store) }
          metrics_task =
            task.async do
              run_metrics_server_with_port_retry(registry:, listen:)
            end

          instance.ready!
          task.wait_all
        rescue Interrupt
          wait_for_reporters_to_disconnect(internal_store)
        ensure
          collector_task&.stop
          metrics_task&.stop
          collector&.stop
        end
      end
    end

    def self.run_metrics_server_with_port_retry(registry:, listen:)
      uri = URI.parse(listen)
      attempts = 0

      loop do
        metrics_server = Server.new(registry:, listen: uri.to_s)

        begin
          metrics_server.run.wait
          return
        rescue Errno::EADDRINUSE
          attempts += 1

          raise if attempts >= MAX_PORT_BIND_ATTEMPTS || !uri.port

          uri.port += 1

          Console.logger.warn(
            self,
            "Metrics port unavailable, retrying with #{uri}"
          )
        end
      end
    end

    def self.wait_for_reporters_to_disconnect(internal_store, timeout: 5)
      return if internal_store.nil? || internal_store.empty?

      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout

      Console.logger.info(
        self,
        "Waiting for metrics reporters to disconnect...",
        active: internal_store.size,
        timeout:
      )

      while internal_store.any?
        break if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
        sleep(0.05)
      end
    end
  end
end
