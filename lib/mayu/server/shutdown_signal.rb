# frozen_string_literal: true

module Mayu
  class Server
    # Signal handlers only write to the pipe. Cleanup runs in the reactor, without
    # cancelling the task tree that is still delivering responses to clients.
    class ShutdownSignal
      def self.open
        signal = new
        signal.install
        yield signal
      ensure
        signal&.close
      end

      def initialize
        @reader, @writer = IO.pipe
        @requested = false
        @handlers = {}
      end

      def install
        [:INT, :TERM].each do |name|
          @handlers[name] = Signal.trap(name) do
            unless @requested
              @requested = true
              @writer.write_nonblock(".", exception: false)
            end
          end
        end
      end

      def requested?
        @requested
      end

      def wait
        @reader.read(1) unless @requested
      end

      def close
        @handlers.each { |name, handler| Signal.trap(name, handler) }
        @reader.close
        @writer.close
      end
    end
  end
end
