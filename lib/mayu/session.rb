# frozen_string_literal: true

#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require_relative "runtime"
require_relative "session/token"
require_relative "session/error_page"
require_relative "session/transfer_state"
require_relative "klenod"

module Mayu
  class Session
    module Events
      class InvalidEventError < StandardError
      end

      class EventRejectedError < StandardError
      end

      CallbackEvent = Data.define(:id, :payload, :ping)
      NavigateEvent = Data.define(:path, :push_state, :ping)
      PingEvent = Data.define(:ping)

      def self.parse(message)
        case message
        in ["Callback", String => id, Hash => event, Numeric => ping] unless id.empty?
          CallbackEvent[id, event, ping]
        in ["Navigate", String => href, true | false => push_state, Numeric => ping]
          NavigateEvent[href, push_state, ping]
        in ["Ping", Numeric => ping]
          PingEvent[ping]
        else
          raise InvalidEventError, "Invalid event message: #{message.inspect}"
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
          render_exceptions: @environment.config.server.render_exceptions?,
          stylesheets: route_stylesheets,
          scripts: route_scripts
        )

      @last_ping = Async::Clock.now
      @incoming_events = Async::Queue.new
    end

    def init_js_path
      "/.mayu/init.js##{@id}"
    end

    def resume_transferred(environment)
      @environment = environment
      @engine.metrics = environment.metrics if @engine.respond_to?(:metrics=)
      @engine.module_provider = module_provider
      @engine.render_exceptions = environment.config.server.render_exceptions?
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
      @incoming_events = Async::Queue.new
    end

    def timed_out?(timeout_seconds = 5)
      diff = Async::Clock.now - @last_ping
      diff > timeout_seconds
    end

    def enqueue_event(event)
      if @transferring
        raise Events::EventRejectedError, "Session is transferring"
      end

      @incoming_events.enqueue(event)
    end

    def receive_message(message)
      enqueue_event(Events.parse(message))
    end

    def dequeue_batch
      @engine.dequeue_batch
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

    def transferring?
      !!@transferring
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

    def listener_commands
      @engine.listener_commands
    end

    def styles
      @engine.styles
    end

    def transfer!
      @transferring = true
      running_task = @task
      stop
      running_task&.wait
      @engine.stop
      @engine.enqueue_command(
        Runtime::Commands::Transfer[
          Mayu::Server::EventStream::Blob[
            TransferState.from_session(self).encrypt(@environment.marshaller)
          ]
        ]
      )
      true
    end

    def transfer_failed!
      @engine.enqueue_command(Runtime::Commands::TransferFailed[])
    end

    private

    def run_code_reload_task(parent)
      return unless module_provider.is_a?(Klenod::DevelopmentProvider)

      run_klenod_reload_task(parent)
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

        loop do
          event = @incoming_events.dequeue

          task.annotate(
            "Session #{@id}: Handling #{event.class.name.split("::").last}"
          ) { handle_event(event) }
        end
      end
    end

    def handle_event(event)
      record_ping(event.ping)

      case event
      in Events::PingEvent
        nil
      in Events::CallbackEvent[id:, payload:]
        @engine.callback(id, payload)
      in Events::NavigateEvent[path:, push_state:]
        Console.logger.info(self, "Navigating to \e[1;34m#{path}\e[0m")

        @environment.metrics.session_navigate_count.increment(labels: {path:})

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
        descriptor = resolve_route(@request_info.path)
        @engine.replace_route_assets(
          stylesheets: route_stylesheets,
          scripts: route_scripts
        )
        @engine.refresh(descriptor)
        @engine.enqueue_command(Runtime::Commands::ReloadSucceeded[])
      else
        emit_reload_error_commands(reload_result)
      end
    rescue => e
      Console.logger.error(self, e)
    end

    def emit_reload_error_commands(reload_result)
      commands =
        Array(reload_result.errors).map do |reload_error|
          module_id, error =
            (reload_error in [_, _]) ? reload_error : [nil, reload_error]

          Console.logger.error(self, error)
          reload_error_command(error, module_id)
        end

      if @engine.render_exceptions? && !commands.empty?
        @engine.enqueue_batch(Runtime::Batch[commands])
      end
    end

    def reload_error_command(error, module_id)
      rewrite_reload_error_backtrace(error)

      file =
        if error.respond_to?(:module_id) && error.module_id
          error.module_id.to_s
        else
          module_id.to_s
        end
      source = error.respond_to?(:source) ? error.source.to_s : ""
      type = (error.respond_to?(:cause) && error.cause || error).class.name

      Runtime::Commands::RenderError[
        file,
        type,
        error.respond_to?(:message) ? error.message : error.inspect,
        error.respond_to?(:backtrace) ? Array(error.backtrace) : [],
        source,
        [{name: "CodeReload", path: file}]
      ]
    end

    def record_ping(timestamp)
      @environment.metrics.session_ping_count.increment
      @last_ping = Async::Clock.now
      @engine.ping(timestamp)
    end

    def rewrite_reload_error_backtrace(error)
      return unless error.is_a?(Exception)

      module_provider.rewrite_exception(error)
    rescue => rewrite_error
      Console.logger.warn(
        self,
        "Could not rewrite reload error backtrace: #{rewrite_error.message}"
      )
    end

    def resolve_route(path)
      provider = module_provider
      return ErrorPage.build("Could not find page for #{path}") unless provider

      router = Klenod::Router.new(provider)
      resolved_page = router.resolve(path)
      return apply_resolved_page(resolved_page) if resolved_page

      ErrorPage.build("Could not find page for #{path}")
    rescue => error
      Console.logger.error(self, error)
      resolved_page = router.error(path, error:)
      raise unless resolved_page

      apply_resolved_page(resolved_page)
    end

    def apply_resolved_page(resolved_page)
      @resolved_page = resolved_page
      @route_status = resolved_page.status
      resolved_page.descriptor
    end

    def route_stylesheets = @resolved_page&.stylesheets || []
    def route_scripts = @resolved_page&.scripts || []
  end
end
