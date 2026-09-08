#!/usr/bin/env ruby -rbundler/setup
# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "minitest/autorun"
require "socket"
require "net/http"
require "tmpdir"

require "async"
require "async/container"
require "async/http"

require_relative "../metrics"

class Mayu::Metrics::AggregationTest < Minitest::Test
  TEST_METRIC_NAME = :mayu_test_worker_boot_count

  def test_aggregates_metrics_from_multiple_workers
    Dir.mktmpdir("mayu-metrics-test") do |root|
      collector_endpoint = Mayu::Metrics.collector_endpoint(root)
      listen = "http://127.0.0.1:#{allocate_port}"

      container = Async::Container::Forked.new

      Mayu::Metrics.start_collect_and_export(
        container,
        collector_endpoint:,
        listen:
      ) do |registry|
        registry.counter(TEST_METRIC_NAME, docstring: "Test worker boot count")
      end

      container.run(
        name: "metrics-worker",
        count: 2,
        restart: false
      ) do |instance|
        session = nil

        begin
          Async do |task|
            session =
              Mayu::Metrics::Reporter.run(
                collector_endpoint,
                task:
              ) do |registry|
                {
                  boot_count:
                    registry.counter(
                      TEST_METRIC_NAME,
                      docstring: "Test worker boot count"
                    )
                }
              end

            session.metrics.fetch(:boot_count).increment
            instance.ready!

            sleep
          end
        rescue Interrupt
        ensure
          session&.stop
        end
      end

      container.wait_until_ready

      wait_until(
        timeout: 8,
        message: "Timed out waiting for aggregated metrics"
      ) do
        metrics = fetch_metrics(listen)

        metrics.match?(/#{TEST_METRIC_NAME}\s+2(?:\.0+)?\b/)
      rescue Errno::ECONNREFUSED, Errno::EINVAL, EOFError
        false
      end
    ensure
      container&.stop(2)
    end
  end

  def test_retries_metrics_port_when_unavailable
    Dir.mktmpdir("mayu-metrics-test") do |root|
      collector_endpoint = Mayu::Metrics.collector_endpoint(root)
      reserved_socket = TCPServer.new("127.0.0.1", 0)
      unavailable_port = reserved_socket.addr[1]

      listen = "http://127.0.0.1:#{unavailable_port}"
      fallback_uri = URI("http://127.0.0.1:#{unavailable_port + 1}/metrics")

      container = Async::Container::Forked.new

      Mayu::Metrics.start_collect_and_export(
        container,
        collector_endpoint:,
        listen:
      ) { |_registry| }

      container.wait_until_ready

      wait_until(
        timeout: 8,
        message: "Timed out waiting for metrics server fallback port"
      ) do
        response = Net::HTTP.get_response(fallback_uri)
        response.is_a?(Net::HTTPSuccess)
      rescue Errno::ECONNREFUSED, Errno::EINVAL, EOFError
        false
      end
    ensure
      reserved_socket&.close
      container&.stop(2)
    end
  end

  private

  def allocate_port
    TCPServer.open("127.0.0.1", 0) { |server| server.addr[1] }
  end

  def fetch_metrics(listen)
    uri = URI("#{listen}/metrics")
    Net::HTTP.get(uri)
  end

  def wait_until(timeout:, message:)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout

    loop do
      return if yield
      break if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
      sleep 0.1
    end

    flunk(message)
  end
end
