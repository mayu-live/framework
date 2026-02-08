# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "async"
require "async/http/endpoint"

require_relative "server/controller"

module Mayu
  class Server
    def initialize(config:, mayu_env:, bundle_filename: nil)
      @uri = URI.parse(config.server.listen)
      ssl_context = ssl_context_for(config)

      endpoint = Async::HTTP::Endpoint.new(@uri, ssl_context:)

      @controller =
        Controller.new(config:, mayu_env:, endpoint:, bundle_filename:)
    end

    def run
      puts "\e[33mStarting server on \e[94m#{@uri}\e[0m"

      @controller.run
    rescue Interrupt
      # Interrupt is expected when Ctrl+C is used for shutdown.
    rescue Errno::EADDRINUSE => e
      puts format("\e[3;31m %s \e[0m", e.message)
      exit 1
    ensure
      Console.logger.info(self, "Stopped server")
    end

    private

    def ssl_context_for(config)
      return nil unless config.server.self_signed_cert?

      self.class.self_signed_cert_ssl_context(@uri.hostname)
    end

    def self.self_signed_cert_ssl_context(hostname)
      require "localhost"

      authority = Localhost::Authority.fetch(hostname)

      ssl_context = authority.server_context

      ssl_context.alpn_select_cb = ->(protocols) do
        protocols.include?("h2") ? "h2" : protocols.first
      end

      ssl_context.alpn_protocols = ["h2"]
      ssl_context.session_id_context = "mayu"

      ssl_context
    end
  end
end
