# typed: strict

require "bundler/setup"
require "sorbet-runtime"

require "optparse"

require 'async'
require 'async/http/endpoint'
require 'falcon'

require_relative "./server2"

module Mayu
  module CLI
    extend T::Sig

    class AbstractCommand
      extend T::Sig
      extend T::Helpers
      abstract!

      sig {abstract.params(argv: T::Array[String]).void}
      def self.call(argv)
      end
    end

    class HelpCommand < AbstractCommand
      extend T::Sig

      sig {override.params(argv: T::Array[String]).void}
      def self.call(argv)
        puts "help"
      end
    end

    class ServeCommand < AbstractCommand
      extend T::Sig

      class Options < T::Struct
        prop :port, Integer, default: 9292
        prop :host, String, default: "127.0.0.1"
        prop :verbose, T::Boolean, default: false
      end

      sig {override.params(argv: T::Array[String]).void}
      def self.call(argv)
        options = Options.new

        opt_parser = OptionParser.new do |parser|
          parser.banner = "Usage: example.rb [options]"

          parser.on("-pPORT", "--port=PORT", "Set the port") do |port|
            options.port = port.to_i
          end

          parser.on("-pHOST", "--host=HOST", "Set the host") do |host|
            options.host = host
          end

          parser.on("-v", "--verbose", "Verbose logging") do |verbose|
            options.verbose = true
          end

          parser.on("-h", "--help", "Prints this help") do
            puts parser
            exit
          end
        end

        opt_parser.parse(argv)

        new(options).call
      end

      sig {params(options: Options).void}
      def initialize(options)
        @options = options
      end

      sig {void}
      def call
        Async do
          url = "http://#{@options.host}:#{@options.port}"

          endpoint = Async::HTTP::Endpoint
            .parse(url)
            .with(protocol: Async::HTTP::Protocol::HTTP2)

          app = Falcon::Server.middleware(Mayu::Server2::App)
          server = Falcon::Server.new(app, endpoint)

          Console.logger.info "Starting server on #{url}"

          server.run.each(&:wait)
        end
      end
    end

    COMMANDS = T.let({
      "dev" => ServeCommand,
      "start" => ServeCommand,
      "help" => HelpCommand,
    }, T::Hash[String, T.class_of(AbstractCommand)])

    sig {params(argv: T::Array[String]).void}
    def self.call(argv)
      cmd, *args = argv

      COMMANDS.fetch(cmd.to_s) {
        puts "Invalid command: #{ARGV.first.inspect}"
        puts "Try: #$0 [#{COMMANDS.keys.join("|")}]"
        exit 1
      }.call(args || [])
    end
  end
end
