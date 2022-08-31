# typed: strict

require "async/task"
require "async/queue"
require_relative "../renderer"

module Mayu
  module Server
    class Renderer
      extend T::Sig

      State = T.type_alias { T::Hash[Symbol, T.untyped] }
      InitialHtmlAndState =
        T.type_alias { { html: String, state: State, vtree: String } }

      sig { returns(State) }
      attr_reader :state

      sig do
        params(
          environment: Mayu::Environment,
          request_path: String,
          state: T.nilable(State),
          vtree: T.nilable(String),
          task: Async::Task
        ).void
      end
      def initialize(
        environment:,
        request_path:,
        state: {},
        vtree: nil,
        task: Async::Task.current
      )
        @environment = environment
        @state = T.let({ request_path: }.merge(state || {}), State)
        @messages = T.let(Async::Queue.new, Async::Queue)
        @renderer =
          T.let(
            Mayu::Renderer.new(
              environment: @environment,
              request_path: request_path.to_s,
              vtree:,
              parent: task
            ),
            Mayu::Renderer
          )
      end

      sig { params(task: Async::Task).returns(InitialHtmlAndState) }
      def initial_html_and_state(task: Async::Task.current)
        @renderer.initial_render => { html:, ids:, stylesheets:, vtree: }

        style =
          stylesheets
            .map do |stylesheet|
              %{<link rel="stylesheet" href="#{stylesheet}">}
            end
            .join

        html =
          html.sub(%r{</head>}) { "#{style}#{_1}" }.prepend("<!DOCTYPE html>\n")

        { html:, state:, vtree: }
      end

      sig { params(event_handler_id: String, payload: T.untyped).void }
      def handle_callback(event_handler_id, payload)
        @renderer.handle_callback(event_handler_id, payload || {})
      end

      sig do
        params(block: T.proc.params(msg: [Symbol, T.untyped]).void).returns(
          Async::Task
        )
      end
      def run(&block)
        @renderer
          .run do |msg|
            Console.logger.error(msg.inspect)
            case msg
            in [:initial_render, payload]
              #   yield [:initial_render, payload]
            in [:init, payload]
              yield [:init, payload]
            in [:patch, payload]
              yield [:patch, payload]
            in [:navigate, payload]
              yield [:navigate, payload]
            in [:exception, payload]
              yield [:exception, payload]
            in [:close]
              binding.pry
              raise Async::Stop
            end
          end
          .wait
      rescue => e
        binding.pry
        Console.logger.fatal(e)
      ensure
        Console.logger.warn("ENDING")
        @renderer.stop
        # task&.stop
      end
    end
  end
end
