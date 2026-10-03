# frozen_string_literal: true

require "async"
require "async/queue"
require "console"
require "pg"

module Database
  # One LISTEN connection per worker, shared by every component listening in
  # it. Only the listener's own task touches the connection: `subscribe`
  # queues LISTEN and UNLISTEN commands, which the task runs between waits
  # for notifications.
  class Listener
    WAIT_SECONDS = 0.5
    RECONNECT_SECONDS = 1

    def self.start(url, on_stop: nil)
      new(url, on_stop:).tap(&:start)
    end

    def initialize(url, on_stop: nil)
      @url = url
      @on_stop = on_stop
      @subscribers = Hash.new { |hash, channel| hash[channel] = Set.new }
      @commands = []
    end

    def start
      @task = Async { run }
    end

    def stop
      @task&.stop
      @on_stop&.call
    end

    def subscribe(channel)
      queue = Async::Queue.new
      add(channel, queue)

      loop { yield queue.dequeue }
    ensure
      remove(channel, queue)
    end

    private

    def add(channel, queue)
      listeners = @subscribers[channel]
      @commands << [:listen, channel] if listeners.empty?
      listeners << queue
    end

    def remove(channel, queue)
      listeners = @subscribers[channel]
      listeners.delete(queue)
      return unless listeners.empty?

      @subscribers.delete(channel)
      @commands << [:unlisten, channel]
    end

    def run
      loop do
        connection = PG.connect(@url)

        begin
          # A new connection listens to nothing, so earlier commands no
          # longer apply.
          @commands.clear
          @subscribers.each_key { |channel| listen(connection, channel) }

          loop do
            run_commands(connection)
            connection.wait_for_notify(WAIT_SECONDS) do |channel, _pid, payload|
              @subscribers.fetch(channel, nil)&.each { it.enqueue(payload) }
            end
          end
        ensure
          connection.close
        end
      # Any error, not only PG::Error: if this task ended, every `subscribe`
      # would wait forever.
      rescue => error
        Console.logger.warn(self, "Lost the LISTEN connection, reconnecting", error)
        sleep RECONNECT_SECONDS
      end
    end

    def run_commands(connection)
      until @commands.empty?
        command, channel = @commands.shift

        case command
        in :listen
          listen(connection, channel)
        in :unlisten
          connection.exec("UNLISTEN #{connection.quote_ident(channel)}")
        end
      end
    end

    def listen(connection, channel)
      connection.exec("LISTEN #{connection.quote_ident(channel)}")
    end
  end
end
