# typed: strict
require_relative "renderer"
require_relative "cluster"

module Mayu
  module Server
    class Session
      extend T::Sig

      sig { returns(String) }
      attr_reader :id
      sig { returns(String) }
      attr_reader :token
      sig { returns(Renderer) }
      attr_reader :renderer

      sig { params(environment: Environment).returns(T.attached_class) }
      def self.init(environment)
        id = SecureRandom.uuid
        token = environment.cluster.generate_session_token

        new(environment, id:, token:)
      end

      StoredState =
        T.type_alias do
          { session: { id: String, token: String }, state: Renderer::State }
        end

      sig do
        params(environment: Environment, stored_state: StoredState).returns(
          T.attached_class
        )
      end
      def self.resume(environment, stored_state)
        stored_state => { session: { id:, token: }, state: }

        new(environment, id:, token:, state:)
      end

      sig do
        params(
          environment: Environment,
          id: String,
          token: String,
          request_path: String,
          state: T.untyped
        ).void
      end
      def initialize(environment, id:, token:, request_path: "/", state: nil)
        @environment = environment
        @cluster = T.let(environment.cluster, Cluster)
        @id = id
        @token = token
        @renderer =
          T.let(Renderer.new(environment:, request_path:, state:), Renderer)
      end

      sig { returns(Cluster::Subject) }
      def subject
        @cluster.session(id, token)
      end

      sig { params(message_cipher: MessageCipher).returns(String) }
      def initial_html(message_cipher)
        renderer.initial_html_and_state => { state:, html: }

        encrypted_data =
          message_cipher.dump({ session: { id:, token: }, state: })

        script_id = "script_" + SecureRandom.alphanumeric(32)

        script = <<~EOF
          <script type="module" src="/__mayu/static/live.js##{encrypted_data}"></script>
        EOF

        html.sub(%r{</body>}) { "#{script}#{_1}" }
      end

      sig { returns({ id: String, token: String, state: Renderer::State }) }
      def transfer_data
        { id:, token:, state: renderer.state }
      end
    end
  end
end
