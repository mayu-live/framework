# frozen_string_literal: true

#
# Copyright Andrés Alin <andreas.alin@gmail.com>
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at https://mozilla.org/MPL/2.0/.

require_relative "runtime"
require_relative "session/event"
require_relative "session/token"
require_relative "session/error_page"
require_relative "session/transfer_state"
require_relative "hot_reload"
require_relative "klenod"

module Mayu
  class Session
    module Events
      class InvalidEventError < StandardError
      end

      class EventRejectedError < StandardError
      end

      ClientCommandApplyMetrics = Data.define(:batches, :commands, :duration_ms)

      # A callback with a settle id is answered with CallbackComplete or
      # CallbackFailed once its handler has returned.
      CallbackEvent =
        Data.define(:id, :payload, :ping, :client_command_apply_metrics, :settle_id) do
          def self.[](id, payload, ping, metrics = nil, settle_id: nil)
            new(id, payload, ping, metrics, settle_id)
          end
        end
      NavigateEvent =
        Data.define(:id, :path, :ping, :client_command_apply_metrics) do
          def self.[](id, path, ping, metrics = nil)
            new(id, path, ping, metrics)
          end
        end
      PingEvent =
        Data.define(:ping, :client_command_apply_metrics) do
          def self.[](ping, metrics = nil)
            new(ping, metrics)
          end
        end
      VisibilityEvent =
        Data.define(:hidden, :ping, :client_command_apply_metrics) do
          def self.[](hidden, ping, metrics = nil)
            new(hidden, ping, metrics)
          end
        end
      InspectEvent =
        Data.define(:id, :query, :ping, :client_command_apply_metrics) do
          def self.[](id, query, ping, metrics = nil)
            new(id, query, ping, metrics)
          end
        end

      def self.parse(message)
        case message
        in ["Callback", String => id, Hash => event, Numeric => ping] unless id.empty?
          CallbackEvent[id, event, ping]
        in ["Callback", String => id, Hash => event, Numeric => ping, String => settle_id] unless id.empty? || invalid_settle_id?(settle_id)
          CallbackEvent[id, event, ping, settle_id:]
        in ["Callback", String => id, Hash => event, Numeric => ping, String => settle_id, telemetry] unless id.empty? || invalid_settle_id?(settle_id)
          CallbackEvent[id, event, ping, parse_client_command_apply_metrics(telemetry), settle_id:]
        in ["Callback", String => id, Hash => event, Numeric => ping, Hash => telemetry] unless id.empty?
          CallbackEvent[id, event, ping, parse_client_command_apply_metrics(telemetry)]
        in ["Navigate", String => id, String => href, Numeric => ping] unless id.empty?
          NavigateEvent[id, href, ping]
        in ["Navigate", String => id, String => href, Numeric => ping, telemetry] unless id.empty?
          NavigateEvent[id, href, ping, parse_client_command_apply_metrics(telemetry)]
        in ["Ping", Numeric => ping]
          PingEvent[ping]
        in ["Ping", Numeric => ping, telemetry]
          PingEvent[ping, parse_client_command_apply_metrics(telemetry)]
        in ["Visibility", true | false => hidden, Numeric => ping]
          VisibilityEvent[hidden, ping]
        in ["Visibility", true | false => hidden, Numeric => ping, telemetry]
          VisibilityEvent[hidden, ping, parse_client_command_apply_metrics(telemetry)]
        in ["Inspect", String => id, Hash => query, Numeric => ping] unless id.empty?
          InspectEvent[id, query, ping]
        in ["Inspect", String => id, Hash => query, Numeric => ping, telemetry] unless id.empty?
          InspectEvent[id, query, ping, parse_client_command_apply_metrics(telemetry)]
        else
          raise InvalidEventError, "Invalid event message: #{message.inspect}"
        end
      end

      def self.parse_client_command_apply_metrics(telemetry)
        case telemetry
        in {
             batches: Integer => batches,
             commands: Integer => commands,
             duration_ms: Numeric => duration_ms
           } if batches.positive? && commands >= batches && duration_ms >= 0
          ClientCommandApplyMetrics[batches, commands, duration_ms]
        else
          raise InvalidEventError,
            "Invalid client command-apply telemetry: #{telemetry.inspect}"
        end
      end
      private_class_method :parse_client_command_apply_metrics

      # Settle ids are short client-chosen strings, echoed back as they are.
      def self.invalid_settle_id?(settle_id)
        settle_id.empty? || settle_id.bytesize > 32
      end
      private_class_method :invalid_settle_id?
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

    # How long the updater waits between passes while the tab is hidden.
    # Nobody sees the page, so several state changes per second collapse
    # into one render and one batch per second; the latest state still wins.
    HIDDEN_UPDATE_INTERVAL_SECONDS = 1

    attr_reader :id, :route_status, :startup_commands
    attr_reader :token

    def initialize(environment:, request_info:)
      @id = SecureRandom.alphanumeric(32)
      @token = Token.generate
      @environment = environment
      @request_info = request_info

      Console.logger.info(
        self,
        event: Event.new(:initializing, session_id: @id, path: @request_info.path)
      )

      @startup_commands = []
      descriptor = resolve_route(@request_info.path)

      begin
        @engine = build_engine(descriptor)
      rescue Runtime::VNodes::VComponent::UnhandledRenderError => failure
        fallback =
          failure.error.is_a?(NotFound) ? not_found_page : error_page_for(failure)
        @engine = build_engine(fallback)
      end
      @engine.not_found_handler = method(:live_not_found_descriptor)

      @last_ping = Async::Clock.now
      @incoming_events = Async::Queue.new
    end

    def build_engine(descriptor)
      Runtime::Engine.new(
        descriptor,
        runtime_js: @request_info.http2 && init_js_path,
        metrics: @environment.metrics,
        module_provider:,
        render_exceptions: @environment.config.server.render_exceptions?,
        validate_dom_nesting: @environment.development?,
        stylesheets: route_stylesheets,
        scripts: route_scripts
      )
    end

    # A component raised while the page was first rendered. It is reported
    # like a render error in a live page, and the route's error page takes
    # over, or a built-in one when the app has none. Either way the session
    # stays alive: in development the overlay follows once the stream
    # connects, and a hot reload that fixes the component renders the real
    # page again.
    def error_page_for(failure)
      vnode = failure.component
      command =
        Runtime::RenderError.report(
          failure.error,
          component: vnode.instance_variable_get(:@instance),
          tree_path: vnode.tree_path,
          provider: module_provider,
          with_source: @environment.config.server.render_exceptions?
        )
      @startup_commands << command if @environment.config.server.render_exceptions?

      provider = module_provider
      resolved_page =
        provider && Klenod::Router.new(provider).error(@request_info.path, error: failure.error)
      return apply_resolved_page(resolved_page) if resolved_page

      @route_status = 500
      ErrorPage.render_failure(
        failure.error,
        details: @environment.config.server.render_exceptions?
      )
    end

    # A component raised NotFound for the current path. The closest
    # +not-found view takes over with status 404, like an unmatched route.
    def not_found_page
      provider = module_provider
      resolved_page =
        provider && Klenod::Router.new(provider).not_found(@request_info.path)
      return apply_resolved_page(resolved_page) if resolved_page

      missing_page(@request_info.path)
    end

    # The VDOM asks for this when a component raises NotFound in a live page.
    # Returns nil while the not-found view is already showing, so a NotFound
    # raised by that view is handled as the render error it is.
    def live_not_found_descriptor
      return nil if @route_status == 404

      descriptor = not_found_page
      @engine.replace_route_assets(
        stylesheets: route_stylesheets,
        scripts: route_scripts
      )
      descriptor
    end

    def missing_page(path)
      @route_status = 404
      ErrorPage.build("Could not find page for #{path}")
    end

    def init_js_path
      "#{@environment.runtime_init_js_path}##{@id}"
    end

    def resume_transferred(environment)
      @environment = environment
      @engine.metrics = environment.metrics if @engine.respond_to?(:metrics=)
      @engine.module_provider = module_provider
      @engine.render_exceptions = environment.config.server.render_exceptions?
      @engine.validate_dom_nesting = environment.development?
      @engine.not_found_handler = method(:live_not_found_descriptor)
      log_restore_report
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
          Console.logger.info(self, event: Event.new(:starting, session_id: @id))

          barrier = Async::Barrier.new

          run_incoming_events_task(barrier)

          @engine.start

          barrier.wait
        rescue => e
          Console.logger.error(self, e)
        ensure
          # Stopping components switches fibers, so a second #stop can arrive
          # while this runs. Defer it so the cleanup always finishes.
          task.defer_cancel do
            Console.logger.info(self, event: Event.new(:stopping, session_id: @id))
            @engine.stop
            barrier.stop
            @task = nil
          end
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
      # The browser must receive the remaining updates before the state.
      @engine.finish_updates!
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

    # Called by the App after a development build applied a source change.
    # Re-resolves the route so the page picks up new module exports, or shows
    # the build errors in the overlay.
    def notify_hmr_update(update)
      handle_reload_result(update) if running?
    end

    private

    # Says which components a transfer could not restore and why, so lost
    # state after a deploy can be traced to the code that changed.
    def log_restore_report
      report = @engine.restore_report if @engine.respond_to?(:restore_report)
      return unless report

      report.reinitialized.each do |entry|
        Console.logger.warn(self, "Session #{@id}: started #{entry.component} over after transfer: #{entry.reason}")
      end
      report.unresolved.each do |entry|
        Console.logger.warn(self, "Session #{@id}: replaced #{entry.component} after transfer: #{entry.reason}")
      end
      Console.logger.info(
        self,
        "Session #{@id}: restored #{report.restored} components, " \
          "started #{report.reinitialized.size} over, replaced #{report.unresolved.size}"
      )
    end

    def handle_reload_result(update)
      if update.success?
        descriptor = resolve_route(@request_info.path)
        @engine.replace_route_assets(
          stylesheets: route_stylesheets,
          scripts: route_scripts
        )
        @engine.refresh(descriptor)
        @engine.enqueue_command(Runtime::Commands::ReloadSucceeded[])
      else
        emit_reload_error_commands(update)
      end
    rescue => e
      Console.logger.error(self, e)
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
      if event.is_a?(Events::InspectEvent)
        # Devtools queries keep the session alive like any event, but aren't
        # answered with a Pong: the page would show them as pings.
        @last_ping = Async::Clock.now
      else
        record_ping(event.ping)
      end
      record_client_command_apply_metrics(event.client_command_apply_metrics)

      case event
      in Events::PingEvent
        nil
      in Events::VisibilityEvent[hidden:]
        @engine.update_interval = hidden ? HIDDEN_UPDATE_INTERVAL_SECONDS : nil
      in Events::CallbackEvent[id:, payload:, settle_id:]
        @engine.callback(id, payload, settle_id:)
      in Events::InspectEvent[id:, query:]
        @engine.enqueue_command(
          Runtime::Commands::InspectResult[id, inspect_engine(query)]
        )
      in Events::NavigateEvent[id:, path:]
        Console.logger.info(self, event: Event.new(:navigating, session_id: @id, path:))

        @environment.metrics.navigations_total.increment

        begin
          @request_info = @request_info.with(path:)
          descriptor = resolve_route(path)
          @engine.replace_route_assets(
            stylesheets: route_stylesheets,
            scripts: route_scripts
          )
          @engine.navigate(descriptor, navigation_id: id)
        rescue
          @engine.enqueue_command(Runtime::Commands::NavigationFailed[id])
          raise
        end
      end
    rescue => e
      Console.logger.error(self, e)
    end

    # Answers a devtools query with the environment's inspector. Sessions
    # without one answer nil, so the client can tell devtools are disabled.
    def inspect_engine(query)
      @environment.inspector&.call(@engine, query)
    rescue => e
      Console.logger.error(self, e)
      {error: "#{e.class}: #{e.message}"}
    end

    def record_client_command_apply_metrics(metrics)
      return unless metrics

      @environment.metrics.client_command_apply_batches_total.increment(
        by: metrics.batches
      )
      @environment.metrics.client_command_apply_commands_total.increment(
        by: metrics.commands
      )
      @environment.metrics.client_command_apply_duration_ms_total.increment(
        by: metrics.duration_ms
      )
    end

    def emit_reload_error_commands(update)
      return unless @engine.render_exceptions?

      commands = update.errors.map { reload_error_command(it) }
      @engine.enqueue_batch(Runtime::Batch[commands]) unless commands.empty?
    end

    # A build error has no component tree to walk, so there is no tree path
    # to show. The overlay hides the section when it is empty.
    def reload_error_command(report)
      Runtime::Commands::RenderError[
        report.file,
        report.type,
        report.detail,
        report.backtrace,
        report.source,
        [],
        report.line,
        report.column,
        report.hints
      ]
    end

    def record_ping(timestamp)
      @environment.metrics.session_pings_total.increment
      @last_ping = Async::Clock.now
      @engine.ping(timestamp)
    end

    def resolve_route(path)
      provider = module_provider
      return missing_page(path) unless provider

      router = Klenod::Router.new(provider)
      resolved_page = router.resolve(path)
      return apply_resolved_page(resolved_page) if resolved_page

      missing_page(path)
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
