# typed: strict
require_relative "../renderer"
require_relative "cluster"

module Mayu
  module Server
    class Session
      extend T::Sig

      sig { returns(String) }
      attr_reader :id
      sig { returns(String) }
      attr_reader :token
      sig { returns(Mayu::Renderer) }
      attr_reader :renderer
      sig { returns(T::Hash[Symbol, T.untyped]) }
      attr_reader :state
      sig { returns(Environment) }
      attr_reader :environment

      sig { params(environment: Environment).returns(T.attached_class) }
      def self.init(environment)
        id = SecureRandom.uuid
        token = environment.cluster.generate_session_token

        new(environment, id:, token:)
      end

      StoredState =
        T.type_alias do
          {
            session: {
              id: String,
              token: String
            },
            state: Renderer::State,
            vtree: String
          }
        end

      sig do
        params(environment: Environment, stored_state: StoredState).returns(
          T.attached_class
        )
      end
      def self.resume(environment, stored_state)
        stored_state => { session: { id:, token: }, state:, vtree: }

        new(environment, id:, token:, state:, vtree:)
      end

      sig do
        params(
          environment: Environment,
          id: String,
          token: String,
          request_path: String,
          state: T.untyped,
          vtree: T.nilable(String)
        ).void
      end
      def initialize(
        environment,
        id:,
        token:,
        request_path: "/",
        state: {},
        vtree: nil
      )
        @environment = environment
        @cluster = T.let(environment.cluster, Cluster)
        @id = id
        @token = token
        @store =
          T.let(environment.create_store(state || {}), Mayu::State::Store)
        @request_path = request_path
        @renderer =
          T.let(
            Mayu::Renderer.new(session: self, request_path:, vtree:),
            Mayu::Renderer
          )
      end

      sig { returns(Cluster::Subject) }
      def subject
        @cluster.session(id, token)
      end

      sig { params(message_cipher: MessageCipher).returns(String) }
      def initial_html(message_cipher)
        @renderer.initial_render => { html:, ids:, stylesheets:, vtree: }

        encrypted_data =
          message_cipher.dump(session: { id:, token: }, state:, vtree:)

        script_id = "script_" + SecureRandom.alphanumeric(32)

        script = <<~EOF
          <script type="module" src="/__mayu/live.js##{encrypted_data}"></script>
        EOF

        style =
          stylesheets
            .map do |stylesheet|
              %{<link rel="stylesheet" href="#{stylesheet}">}
            end
            .join

        html
          .sub(%r{</head>}) { "#{style}#{_1}" }
          .sub(%r{\K</body>}) { "#{script}#{_1}" }
          .prepend("<!DOCTYPE html>\n")
      end

      sig do
        params(block: T.proc.params(msg: [Symbol, T.untyped]).void).returns(
          Async::Task
        )
      end
      def run(&block)
        @renderer.run { |msg| yield msg }.wait
      rescue => e
        binding.pry
        Console.logger.fatal(e)
      ensure
        Console.logger.warn("ENDING")
        @renderer.stop
        # task&.stop
      end

      sig { params(event_handler_id: String, payload: T.untyped).void }
      def handle_callback(event_handler_id, payload)
        @renderer.handle_callback(event_handler_id, payload || {})
      end

      sig { returns({ id: String, token: String, state: Renderer::State }) }
      def transfer_data
        { id:, token:, state: }
      end
    end
  end
end
