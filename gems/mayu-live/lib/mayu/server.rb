# frozen_string_literal: true

# Copyright Andrés Alin <andreas.alin@gmail.com>
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

require "async"
require "async/http/endpoint"
require "console"
require "console/output/split"
require "fileutils"

# Console picks up event formatters when it creates its terminal output,
# which happens on the first log line. The runtime itself is loaded lazily by
# the worker, so its formatter is loaded here, before the server logs.
require_relative "runtime/render_error_formatter"
require_relative "server/controller"

module Mayu
  class Server
    # `load_environment` is called once per worker process with `metrics:`
    # and returns the Environment that worker serves. The CLI decides what
    # goes in it, so the server itself never knows whether it is running a
    # prebuilt bundle or a live build.
    def initialize(config:, load_environment:, worker_count: nil)
      @config = config
      @load_environment = load_environment
      @worker_count = worker_count
      @uri = URI.parse(config.server.listen)
    end

    def run
      install_log_file

      puts "\e[33mStarting server on \e[94m#{@uri}\e[0m"

      controller.run
    rescue Interrupt
      # Interrupt is expected when Ctrl+C is used for shutdown.
    rescue Errno::EADDRINUSE, MissingLocalhostGemError => e
      puts format("\e[3;31m %s \e[0m", e.message)
      exit 1
    ensure
      Console.logger.info(self, "Stopped server")
    end

    class MissingLocalhostGemError < StandardError
      def initialize
        super(
          "self_signed_cert needs the localhost gem. It comes with mayu-build; " \
          "for a server without mayu-build, add the localhost gem to your " \
          "Gemfile or turn off self_signed_cert and terminate TLS elsewhere."
        )
      end
    end

    # Self-signed certificates are a development convenience, so the gem
    # generating them ships with mayu-build rather than mayu-live.
    def self.self_signed_cert_ssl_context(hostname)
      begin
        require "localhost"
      rescue LoadError => error
        raise unless error.path == "localhost"

        raise MissingLocalhostGemError
      end

      authority = Localhost::Authority.fetch(hostname)

      ssl_context = authority.server_context

      ssl_context.alpn_select_cb = ->(protocols) do
        protocols.include?("h2") ? "h2" : protocols.first
      end

      ssl_context.alpn_protocols = ["h2"]
      ssl_context.session_id_context = "mayu"

      ssl_context
    end

    private

    # Logs go to the terminal as before and, when `log_file` is configured,
    # to that file as plain text as well. `Console.logger=` is fiber-local, so
    # this runs before the reactor starts and before workers fork; every task
    # and worker process inherits the logger from here.
    def install_log_file
      path = @config.log_file
      return unless path

      FileUtils.mkdir_p(File.dirname(path))
      file = File.open(path, "a")
      file.sync = true

      Console.logger =
        Console::Logger.new(
          Console::Output::Split[
            Console::Output::Default.new($stderr),
            Console::Output::Text.new(file)
          ],
          level: Console::Logger.default_log_level
        )
    end

    # Built here rather than in `initialize` so a missing localhost gem is
    # reported by `run` like any other startup failure.
    def controller
      endpoint =
        Async::HTTP::Endpoint.new(@uri, ssl_context: ssl_context_for(@config))

      Controller.new(
        config: @config,
        endpoint:,
        load_environment: @load_environment,
        worker_count: @worker_count
      )
    end

    def ssl_context_for(config)
      return nil unless config.server.self_signed_cert?

      self.class.self_signed_cert_ssl_context(@uri.hostname)
    end
  end
end
