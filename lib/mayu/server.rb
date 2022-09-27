# typed: strict

require "bundler/setup"
require "sorbet-runtime"
require "async"
require "async/container"
require "async/http/server"
require "async/http/endpoint"
require "protocol/http/body/file"
require "async/io/host_endpoint"
require "async/io/shared_endpoint"
require "async/io/ssl_endpoint"
require "async/io/trap"
require "localhost"
require "mime/types"
require_relative "environment"
require_relative "session"
require_relative "configuration"
require_relative "colors"
require_relative "server/controller"

module Mayu
  module Server
    extend T::Sig

    sig { params(config: Configuration).void }
    def self.start_dev(config) = start(config)

    sig { params(config: Configuration).void }
    def self.start_prod(config) = start(config)

    sig { params(config: Configuration).void }
    def self.start(config)
      uri = config.server.uri
      ssl_context =
        if config.server.self_signed_cert
          setup_self_signed_cert(uri.host.to_s)
        end
      endpoint = Async::HTTP::Endpoint.new(uri, ssl_context:, reuse_port: true)

      Configuration.log_config(config)
      Process.setproctitle("mayu #{config.mode} file://#{config.root} #{uri}")

      Controller.new(config:, endpoint:).run
    end

    sig { params(host: String).returns(OpenSSL::SSL::SSLContext) }
    def self.setup_self_signed_cert(host)
      authority = Localhost::Authority.fetch(host)

      authority.server_context.tap do |context|
        context.alpn_select_cb = lambda { |_| "h2" }
        lambda { |protocols| protocols.include?("h2") ? "h2" : nil }

        context.alpn_protocols = ["h2"]
        context.session_id_context = "mayu"
      end
    end
  end
end
