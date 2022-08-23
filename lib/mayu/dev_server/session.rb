# typed: false

require_relative "../renderer"

module Mayu
  module DevServer
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
        @environment = environment
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
            in [:exception, payload]
              push(:exception, payload)
            in [:close]
              subtask.stop
            end
          end
        rescue => e
          p e
          raise
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
          push(:pong, { time: payload.to_i, region: @environment.region })
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
  end
end
