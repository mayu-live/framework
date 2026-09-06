# frozen_string_literal: true
#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require_relative "runtime"
require_relative "session/token"
require_relative "session/error_page"
require_relative "session/transfer_state"
require_relative "modules"
require_relative "klenod"

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
      Data.define(:path, :headers, :http2) do
        def self.from_request(request)
          new(
            path: request.path,
            headers: request.headers.to_h.freeze,
            http2: request.version == "HTTP/2"
          )
        end
      end

    attr_reader :id, :route_status
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

      descriptor = resolve_route(@request_info.path)
      runtime_js = @request_info.http2 && init_js_path

      @engine =
        Runtime::Engine.new(
          descriptor,
          runtime_js:,
          metrics: @environment.metrics,
          module_provider:,
          stylesheets: route_stylesheets,
          scripts: route_scripts
        )

      @last_ping = Async::Clock.now
    end

    def init_js_path
      "/.mayu/init.js##{@id}"
    end

    def resume_transferred(environment)
      @environment = environment
      @engine.metrics = environment.metrics if @engine.respond_to?(:metrics=)
      @engine.module_provider = module_provider
      self
    end

    def module_provider
      @environment.module_provider if @environment.respond_to?(:module_provider)
    end

    def component_resolver
      provider = module_provider
      provider.component_resolver if provider&.respond_to?(:component_resolver)
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

    def dequeue_patch
      @engine.dequeue_patch
    end

    def start
      raise "Session already running" if @task

      @task =
        Async do |task|
          task.annotate("Session #{@id}")
          Console.logger.info(self, "Starting session")

          barrier = Async::Barrier.new

          run_code_reload_task(barrier) if @environment.config.server.hmr?
          run_incoming_events_task(barrier)

          @engine.start

          barrier.wait
        rescue => e
          Console.logger.error(self, e)
        ensure
          Console.logger.info(self, "Stopping session")
          @engine.stop
          barrier.stop
          @task = nil
        end
    end

    def running?
      !!@task
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

    def dom_id_tree
      @engine.dom_id_tree
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
      if module_provider.is_a?(Klenod::DevelopmentProvider)
        return run_klenod_reload_task(parent)
      end

      parent.async do |task|
        task.annotate("Session #{@id}: HMR")

        while (reload_result = Modules::System.current.wait_for_reload)
          handle_reload_result(reload_result)
        end
      end
    end

    def run_klenod_reload_task(parent)
      parent.async do |task|
        task.annotate("Session #{@id}: HMR")
        updates = Async::Queue.new
        subscription =
          @environment.subscribe_klenod_updates do |update|
            updates.enqueue(update)
          end

        while (update = updates.dequeue)
          handle_reload_result(update)
        end
      ensure
        @environment.unsubscribe_klenod_updates(subscription) if subscription
        updates&.close
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
        @engine.replace_route_assets(
          stylesheets: route_stylesheets,
          scripts: route_scripts
        )
        @engine.navigate(path, descriptor, push_state:)
      end
    rescue => e
      Console.logger.error(self, e)
    end

    def handle_reload_result(reload_result)
      if reload_result.success?
        puts "\e[30;103mCode update detected, reloading.\e[0m"
        descriptor = resolve_route(@request_info.path)
        @engine.replace_route_assets(
          stylesheets: route_stylesheets,
          scripts: route_scripts
        )
        @engine.refresh(descriptor)
        @engine.patch(Runtime::Patches::Event["reload:success", nil])
      else
        emit_reload_error_patches(reload_result)
      end
    rescue => e
      Console.logger.error(self, e)
    end

    def emit_reload_error_patches(reload_result)
      Array(reload_result.errors).each do |reload_error|
        if reload_error in [module_id, error]
          file =
            (
              if error.respond_to?(:module_id)
                error.module_id.to_s
              else
                module_id.to_s
              end
            )
          source = error.respond_to?(:source) ? error.source.to_s : ""
          type =
            (
              if error.respond_to?(:cause)
                error.cause.class.name
              else
                error.class.name
              end
            )
          @engine.patch(
            Runtime::Patches::RenderError[
              file,
              type,
              error.message,
              Array(error.backtrace),
              source,
              [{ name: "CodeReload", path: file }]
            ]
          )
          next
        end

        @engine.patch(
          Runtime::Patches::RenderError[
            reload_error.file,
            reload_error.type,
            reload_error.message,
            Array(reload_error.backtrace),
            reload_error.source.to_s,
            [{ name: "CodeReload", path: reload_error.file }]
          ]
        )
      end
    end

    def resolve_route(path)
      if provider = module_provider
        resolved_page = Klenod::Router.new(provider).resolve(path)
        if resolved_page
          @resolved_page = resolved_page
          @route_status = resolved_page.status
          return resolved_page.descriptor
        end
      end

      @resolved_page = nil
      @route_status = 200

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

    def route_stylesheets = @resolved_page&.stylesheets || []
    def route_scripts = @resolved_page&.scripts || []
  end
end
