# typed: false

require_relative "../mayu"
require_relative "environment"
require_relative "renderer"
require_relative "state/loader"

module Mayu
  module Server2
    class Session
      class << self
        def __SESSIONS__
          $__mayu__sessions__ ||= {}
        end

        def fetch(id, key)
          session = __SESSIONS__.fetch(id) { return yield :session_not_found }

          return yield :invalid_session_key unless session.key == key

          session
        end

        def store(session)
          __SESSIONS__.store(session.id, session)
        end

        def delete(id)
          __SESSIONS__.delete(id)&.stop
        end
      end

      def self.init(environment:, request_path:, task: Async::Task.current)
        self.store(new(environment:, request_path:, task:))
      end

      def self.connect(id, key, task: Async::Task.current)
        self.fetch(id, key) { return _1 }.connect(task:)
      end

      def self.handle_callback(id, key, callback_id, payload)
        self.fetch(id, key) { return _1 }.handle_callback(callback_id, payload)
      end

      def self.cookie_name(id) = "mayu-session-#{id}"

      DEFAULT_TIMEOUT_IN_SECONDS = 10

      attr_reader :id
      attr_reader :key

      def initialize(
        environment:,
        request_path:,
        timeout_in_seconds: DEFAULT_TIMEOUT_IN_SECONDS,
        task: Async::Task.current
      )
        @id = SecureRandom.uuid
        @key = SecureRandom.uuid
        @timeout_in_seconds = timeout_in_seconds
        @semaphore = Async::Semaphore.new(1)
        @messages = Async::Queue.new
        @task = task
        @timeout_task = nil

        @renderer = Renderer.new(environment:, request_path:, parent: @task)

        @task.async do |subtask|
          loop do
            case @renderer.take
            in [:initial_render, payload]
              push(:initial_render, payload)
            in [:init, payload]
              push(:init, payload)
            in [:patch, payload]
              push(:patch, payload)
            in [:navigate, payload]
              push(:navigate, payload)
            in [:close]
              subtask.stop
            end
          end
        ensure
          @task.stop
        end

        start_timeout
      end

      def stop = @task.stop
      def cookie_name = self.class.cookie_name(id)

      def push(event, data = {})
        @messages.enqueue([SecureRandom.uuid, event, data])
      end

      def initial_render
        body = Async::HTTP::Body::Writable.new

        @task.async do
          @messages.dequeue => [_id, :initial_render, patches]

          rendered_html = ""
          stylesheets = Set.new

          patches.each do |patch|
            case patch
            in { type: :insert, html: }
              rendered_html = html
            in { type: :stylesheet, paths: }
              paths.each { stylesheets.add(_1) }
            end
          end

          raise "Rendered html is empty" if rendered_html.empty?

          style =
            stylesheets
              .map do |stylesheet|
                %{<link rel="stylesheet" href="#{stylesheet}">}
              end
              .join

          script =
            %{<script type="module" src="/__mayu/live.js?#{@id}"></script>}

          body.write(
            rendered_html
              .prepend("<!DOCTYPE html>\n")
              .sub(%r{</head>}) { "#{script}#{_1}" }
              .sub(%r{</head>}) { "#{style}#{_1}" }
          )
        ensure
          body.close
        end

        body
      end

      def connect(task: Async::Task.current)
        return :too_many_connections if @semaphore.blocking?

        body = Async::HTTP::Body::Writable.new

        @semaphore.async do
          @timeout_task&.stop

          task
            .async do
              loop do
                @messages.dequeue => [id, event, data]
                body.write(format_message(id, event, data))
              end
            rescue Async::HTTP::Body::Writable::Closed
              puts "Write error, closing"
            ensure
              body.close
              start_timeout
            end
            .wait
        end

        body
      end

      def handle_callback(callback_id, payload)
        if callback_id == "ping"
          push(:pong, {
            time: payload.to_i,
            region: ENV.fetch("FLY_REGION", 'localhost'),
          })
        else
          @renderer.handle_callback(callback_id, payload)
        end
      end

      private

      def format_message(id, event, data)
        <<~MSG.strip + "\n\n"
          id: #{SecureRandom.uuid}
          event: #{event}
          data: #{JSON.generate(data)}
        MSG
      end

      def start_timeout
        return if @timeout_task

        @timeout_task =
          @task.async do |subtask|
            @timeout_in_seconds.times { subtask.sleep 1 }

            self.class.delete(id)
          ensure
            @timeout_task = nil
          end
      end
    end

    class AssetsApp
      MOUNT_PATH = "/__mayu/assets"

      def call(env)
        asset =
          Mayu::Assets::Manager.find(File.basename(env[Rack::PATH_INFO].to_s))

        return 404, {}, ["File not found"] unless asset

        accept = env["HTTP_ACCEPT"].to_s.split(",")

        unless accept.include?("*/*") || accept.include?(asset.content_type)
          return [
            406,
            {},
            ["Not acceptable, try requesting #{asset.content_type} instead"]
          ]
        end

        headers = {
          "content-type" => asset.content_type,
          "cache-control" => "public, max-age=604800, immutable"
        }

        [200, headers, [asset.content]]
      end
    end

    class EventStreamApp
      MOUNT_PATH = "/__mayu/events"

      EVENT_STREAM_HEADERS = {
        "content-type" => "text/event-stream",
        "connection" => "keep-alive",
        "cache-control" => "no-cache",
        "x-accel-buffering" => "no"
      }

      def call(env)
        request = Rack::Request.new(env)
        session_id = request.path_info.to_s.split("/", 2).last
        cookie_name = Session.cookie_name(session_id)

        session_key =
          request
            .cookies
            .fetch(cookie_name) { return 401, {}, ["Session cookie not set"] }

        case Session.connect(session_id, session_key)
        in :session_not_found
          [404, {}, ["Session not found"]]
        in :bad_session_key
          [403, {}, ["Bad session key"]]
        in :too_many_connections
          [429, {}, ["Too many connections"]]
        in Async::HTTP::Body::Writable => body
          [200, { "content-type" => "text/event-stream; charset=utf-8" }, body]
        else
          [500, {}, ["Internal server error"]]
        end
      end
    end

    class PingHandlerCallback
      MOUNT_PATH = "/__mayu/ping"

      def call(env)
        request = Rack::Request.new(env)
        session_id, handler_id = request.path_info.to_s.split("/", 3).last(2)
        cookie_name = Session.cookie_name(session_id)
        session_key =
          request
            .cookies
            .fetch(cookie_name) { return 401, {}, ["Session cookie not set"] }

        payload = JSON.parse(request.body.read)

        Session.ping(session_id, session_key, payload)
      end

      [200, {}, ["ok"]]
    end

    class ResumeApp
      MOUNT_PATH = "/__mayu/resume"

      def call(env)
        request = Rack::Request.new(env)
        location = request.params[:path] || "/"
        cookie_name = Session.cookie_name(session_id)
        session_key =
          request
            .cookies
            .fetch(cookie_name) { return 401, {}, ["Session cookie not set"] }
        Console.logger.info(self) { "Resuming not implemented yet!!" }
        return 302, { "location" => location }, ["resuming not implemented"]
      end
    end

    class CallbackHandlerApp
      MOUNT_PATH = "/__mayu/handler"

      def call(env)
        request = Rack::Request.new(env)
        session_id, handler_id = request.path_info.to_s.split("/", 3).last(2)
        cookie_name = Session.cookie_name(session_id)
        session_key =
          request
            .cookies
            .fetch(cookie_name) { return 401, {}, ["Session cookie not set"] }

        payload = JSON.parse(request.body.read)

        case Session.handle_callback(
          session_id,
          session_key,
          handler_id,
          payload
        )
        when :session_not_found
          [404, {}, ["Session not found"]]
        else
          [200, {}, ["ok"]]
        end
      end
    end

    class InitSessionApp
      def initialize(root:, hot_reload:)
        @environment = Environment.new(root:, hot_reload:)
      end

      def call(env)
        request = Rack::Request.new(env)

        if request.path_info == "/favicon.ico"
          return [
            404,
            { "content-type" => "text/plain" },
            ["There is no favicon"]
          ]
        end

        unless env["REQUEST_METHOD"].to_s == "GET"
          return 405, {}, ["Only GET requests are supported."]
        end

        unless env["HTTP_ACCEPT"].to_s.split(",").include?("text/html")
          return 406, {}, ["Not acceptable, try requesting HTML instead"]
        end

        session =
          Session.init(
            environment: @environment,
            request_path: request.path_info
          )

        response =
          Rack::Response.new(
            session.initial_render,
            200,
            {
              "content-type" => "text/html; charset=utf-8",
              "cache-control" => "no-store"
            }
          )

        response.set_cookie(
          session.cookie_name,
          {
            path: "/__mayu/",
            secure: true,
            http_only: true,
            same_site: :strict,
            value: session.key
          }
        )

        response.finish
      end
    end

    JS_ROOT_DIR = File.join(File.dirname(__FILE__), "client", "dist")
    APP_DIR = "app"
    PUBLIC_DIR = "public"
    STORE_DIR = "store"

    def self.rack_static_options_for_js
      urls =
        Dir[File.join(JS_ROOT_DIR, "*.js")]
          .map { File.basename(_1) }
          .map { ["/__mayu/#{_1}", _1] }
          .to_h
          .merge("/__mayu.serviceWorker.js" => "sw.js")
      p urls
      { root: JS_ROOT_DIR, urls: }
    end

    def self.build(root:, hot_reload:)
      public_root_dir = File.join(root, PUBLIC_DIR)

      Rack::Builder.new do
        map EventStreamApp::MOUNT_PATH do
          run EventStreamApp.new
        end

        map CallbackHandlerApp::MOUNT_PATH do
          run CallbackHandlerApp.new
        end

        map ResumeApp::MOUNT_PATH do
          run ResumeApp.new
        end

        map AssetsApp::MOUNT_PATH do
          run AssetsApp.new
        end

        use Rack::Static, Mayu::Server2.rack_static_options_for_js

        use Rack::Static, urls: [""], root: public_root_dir, cascade: true

        run InitSessionApp.new(root:, hot_reload:)
      end
    end
  end
end
