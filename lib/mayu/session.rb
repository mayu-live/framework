# frozen_string_literal: true
#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require_relative "runtime"
require_relative "session/token"
require_relative "session/error_page"
require_relative "session/transfer_state"

module Mayu
  class Session
    module Events
      CallbackEvent = Data.define(:id, :payload)
      NavigateEvent = Data.define(:path, :push_state)
      PingEvent = Data.define(:ping)

      def self.from_message(message)
        case message
        in { type: "callback", payload: { id:, event: }, ping: }
          [PingEvent[ping], CallbackEvent[id, event]]
        in {
             type: "navigate", payload: { href:, pushState: push_state }, ping:
           }
          [PingEvent[ping], NavigateEvent[href, push_state]]
        in { type: "ping", ping: }
          [PingEvent[ping]]
        else
          Console.logger.error(self, "Unknown message: #{message.inspect}")
          []
        end
      end
    end

    RequestInfo =
      Data.define(:path, :headers) do
        def self.from_request(request)
          new(path: request.path, headers: request.headers.to_h.freeze)
        end
      end

    attr_reader :id
    attr_reader :token

    def initialize(environment:, request_info:)
      @id = SecureRandom.alphanumeric(32)
      @token = Token.generate
      @environment = environment
      @request_info = request_info

      Console.logger.info(
        self,
        "Initializing session #{@id} at \e[1;34m#{@request_info.path}\e[0m"
      )

      @engine =
        Runtime.init(
          resolve_route(@request_info.path),
          metrics: @environment.metrics,
          runtime_js: environment.runtime_js_for_session_id(@id)
        )

      @last_ping = Async::Clock.now
    end

    def resume_transferred(environment)
      @environment = environment
      @engine.metrics = environment.metrics
      self
    end

    def valid_token?(token)
      Session::Token.equal?(@token, token)
    end

    def marshal_dump
      [@id, @token, @engine, @last_ping, @request_info]
    end

    def marshal_load(a)
      @id, @token, @engine, @last_ping, @request_info = a
    end

    def timed_out?(timeout_seconds = 5)
      diff = Async::Clock.now - @last_ping
      diff > timeout_seconds
    end

    def enqueue_event(event)
      @incoming_events.enqueue(event)
    end

    def run(&block)
      raise "Session already running" if @task

      @task =
        Async do |task|
          task.annotate("Session #{@id}")

          barrier = Async::Barrier.new

          run_code_reload_task(barrier) if @environment.config.server.hmr?

          run_incoming_events_task(barrier)

          @engine.run(&block)
        ensure
          barrier.stop
          Console.logger.error(self, "Stop session")
          @task = nil
        end
    end

    def wait
      @task&.wait
    end

    def stop
      @task&.stop
    end

    def render
      @engine.render
    end

    def styles
      @engine.styles
    end

    def transfer!
      @engine.stop
      @engine.patch(
        Runtime::Patches::Transfer[
          Mayu::Server::EventStream::Blob[
            TransferState.from_session(self).encrypt(@environment.marshaller)
          ]
        ]
      )
    rescue EncryptedMarshal::DumpError => e
      Console.logger.error(self, "Error transferring session: #{@id}", e)
      @engine.patch(Runtime::Patches::TransferFailed[])
    rescue => e
      Console.logger.error(self, e)
    end

    private

    def run_code_reload_task(parent)
      parent.async do |task|
        task.annotate("Session #{@id}: HMR")

        while Modules::System.current.wait_for_reload
          puts "\e[30;103mCode update detected, reloading.\e[0m"
          @engine.update(resolve_route(@request_info.path))
        end
      end
    end

    def run_incoming_events_task(parent)
      parent.async do |task|
        task.annotate("Session #{@id}: Handle incoming events")

        @incoming_events = Async::Queue.new

        loop do
          event = @incoming_events.dequeue

          task.annotate(
            "Session #{@id}: Handling #{event.class.name.split("::").last}"
          ) { handle_event(event) }
        end
      ensure
        @incoming_events = nil
        Console.logger.error(self, "Stop handling incoming events")
      end
    end

    def handle_event(event)
      case event
      in Events::PingEvent[ping:]
        @environment.metrics.session_ping_count.increment
        @last_ping = Async::Clock.now
        @engine.ping(ping)
      in Events::CallbackEvent[id:, payload:]
        @engine.callback(id, payload)
      in Events::NavigateEvent[path:, push_state:]
        Console.logger.info(self, "Navigating to \e[1;34m#{path}\e[0m")

        @environment.metrics.session_navigate_count.increment(labels: { path: })

        @request_info = @request_info.with(path:)
        descriptor = resolve_route(path)
        @engine.navigate(path, descriptor, push_state:)
      end
    rescue => e
      Console.logger.error(self, e)
    end

    def resolve_route(path)
      system = Modules::System.current

      match = @environment.router.match(path)

      return ErrorPage.build("Could not find page for #{path}") unless match

      layouts = [
        system.import("root.haml"),
        *match.route.layouts.map { system.import(File.join("/pages", _1)) }
      ]

      page =
        Mayu::Runtime::H[
          system.import(File.join("/pages", match.route.views.page)),
          params: match.params,
          query: match.query
        ]

      layouts
        .reverse
        .reduce(page) do |page, layout|
          Mayu::Runtime::H[
            layout,
            page,
            params: match.params,
            query: match.query,
            path:
          ]
        end
    end
  end
end
