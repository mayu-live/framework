# frozen_string_literal: true

require "async/http/server"

module Mayu
  class Server
    class HTTPServer < Async::HTTP::Server
      def initialize(...)
        super
        # A task scope releases finished children as connections close, while
        # keeping live connections independent of the accept loop.
        @connections = Async::Task.current.async { |task| task.sleep }
        @accepting = true
      end

      # Accepted connections belong to the worker, not the listener task. TLS
      # handshakes that have not reached this method can be cancelled with it.
      def accept(peer, address, **options)
        unless @accepting
          peer.close
          return
        end

        @connections.async do
          super(peer, address, **options)
        rescue IOError, SystemCallError => error
          Console.logger.debug(self, error)
        ensure
          peer.close unless peer.closed?
        end
      end

      def stop_accepting
        @accepting = false
        @listener&.stop
        @endpoint.close
      end

      def run
        @listener = super
      end

      def stop
        stop_accepting
      ensure
        @connections.stop
      end
    end
  end
end
