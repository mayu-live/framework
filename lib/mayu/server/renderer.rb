# typed: strict

require "async/task"
require "async/queue"
require_relative "../renderer"

module Mayu
  module Server
    class Renderer
      extend T::Sig

      State = T.type_alias { T::Hash[Symbol, T.untyped] }
      InitialHtmlAndState = T.type_alias { { html: String, state: State } }

      sig { returns(State) }
      attr_reader :state

      sig do
        params(
          environment: Mayu::Environment,
          request_path: String,
          state: T.nilable(State)
        ).void
      end
      def initialize(environment:, request_path:, state: {})
        @environment = environment
        @state = T.let({ request_path: }.merge(state || {}), State)
        @messages = T.let(Async::Queue.new, Async::Queue)
        @renderer = T.let(nil, T.nilable(Mayu::Renderer))
      end

      sig { params(task: Async::Task).returns(InitialHtmlAndState) }
      def initial_html_and_state(task: Async::Task.current)
        renderer =
          Mayu::Renderer.new(
            environment: @environment,
            request_path: state[:request_path].to_s,
            parent: task
          )
        renderer.take => [:initial_render, patches]
        renderer.take => [:init, ids]
        renderer.stop

        rendered_html = ""
        stylesheets = Set.new

        patches.each do |patch|
          case patch
          in { type: :insert, html: }
            rendered_html = T.cast(html, String)
          in { type: :stylesheet, paths: }
            paths.each { stylesheets.add(_1) }
          end
        end

        style =
          stylesheets
            .map do |stylesheet|
              %{<link rel="stylesheet" href="#{stylesheet}">}
            end
            .join

        html =
          rendered_html
            .prepend("<!DOCTYPE html>\n")
            .sub(%r{</head>}) { "#{style}#{_1}" }

        { html:, state: }
      end

      sig { params(event_handler_id: String, payload: T.untyped).void }
      def handle_callback(event_handler_id, payload)
        @renderer.handle_callback(event_handler_id, payload || {})
      end

      sig do
        params(
          task: Async::Task,
          block: T.proc.params(msg: [Symbol, T.untyped]).void
        ).returns(Async::Task)
      end
      def run(task: Async::Task.current, &block)
        @renderer =
          T.let(
            Mayu::Renderer.new(
              environment: @environment,
              request_path: state[:request_path].to_s,
              parent: task
            ),
            Mayu::Renderer
          )

        msg = @renderer.take
        msg => [:initial_render, _patches]

        task.async do |subtask|
          loop do
            msg = @renderer.take
            Console.logger.warn(msg.inspect)
            case msg
            in [:initial_render, payload]
              yield [:initial_render, payload]
            in [:init, payload]
              yield [:init, payload]
            in [:patch, payload]
              yield [:patch, payload]
            in [:navigate, payload]
              yield [:navigate, payload]
            in [:exception, payload]
              yield [:exception, payload]
            in [:close]
              subtask.stop
            end
          rescue => e
            Console.logger.fatal("ENDING", e)
            raise
          end
        ensure
          Console.logger.warn("ENDING")
          @renderer.stop
          @renderer = nil
          task.stop
        end
      end
    end
  end
end
