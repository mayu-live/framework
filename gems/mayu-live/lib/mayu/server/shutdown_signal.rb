# frozen_string_literal: true

require "async/signals"

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
        @registration = nil
      end

      def install
        handlers = Async::Signals::Handlers.new
        [:INT, :TERM].each do |name|
          handlers.trap(name) do
            unless @requested
              @requested = true
              @writer.write_nonblock(".", exception: false)
            end
          end
        end
        @registration = Async::Signals.install(handlers)
      end

      def requested?
        @requested
      end

      def wait
        @reader.read(1) unless @requested
      end

      # Once a shutdown was requested the handlers stay installed. The
      # controller's interrupt can still arrive while this process exits,
      # after the terminal already delivered Ctrl-C to the whole group.
      # Restoring the previous trap would let that raise Interrupt past the
      # exit path and end the process with a signal status. The handlers do
      # nothing after the first signal, so they are safe to leave in place
      # for the rest of a process that is about to exit anyway.
      def close
        @registration&.close unless @requested
        @reader.close
        @writer.close
      end
    end
  end
end
