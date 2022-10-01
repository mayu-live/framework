# typed: strict

require "time"
require "nanoid"
require_relative "environment"
require_relative "vdom/vtree"
require_relative "vdom/marshalling"

module Mayu
  class Session
    extend T::Sig

    class InvalidTokenError < StandardError
    end

    class InvalidIdError < StandardError
    end

    sig do
      params(environment: Environment, path: String).returns(T.attached_class)
    end
    def self.init(environment:, path:)
      new(environment:, path:)
    end

    sig do
      params(environment: Environment, dumped: String).returns(T.attached_class)
    end
    def self.restore(environment:, dumped:)
      Marshal.restore(
        dumped,
        ->(obj) do
          case obj
          when self
            obj.instance_variable_set(:@environment, environment)
            obj
          when SerializedSession
            obj.to_session(environment)
          else
            obj
          end
        end
      )
    end

    ID_FORMAT = /\A[A-Za-z0-9_-]{21}\z/

    TOKEN_LENGTH = 64
    TOKEN_FORMAT = /\A\w{#{TOKEN_LENGTH}}\z/

    sig { returns(String) }
    def self.generate_token
      SecureRandom.alphanumeric(TOKEN_LENGTH)
    end

    sig { params(token: String).returns(T::Boolean) }
    def self.valid_token?(token)
      token.match?(TOKEN_FORMAT)
    end

    sig { params(token: String).void }
    def self.validate_token!(token)
      raise InvalidTokenError unless valid_token?(token)
    end

    sig { params(id: String).returns(T::Boolean) }
    def self.valid_id?(id)
      id.match?(ID_FORMAT)
    end

    sig { params(id: String).void }
    def self.validate_id!(id)
      raise InvalidIdError unless valid_id?(id)
    end

    Marshaled = T.type_alias { [String, String, String, String, String] }

    sig { returns(String) }
    attr_reader :id
    sig { returns(String) }
    attr_reader :token
    sig { returns(String) }
    attr_reader :path
    sig { returns(Environment) }
    attr_reader :environment
    sig { returns(Float) }
    attr_reader :last_ping_at

    sig { params(timeout_seconds: T.any(Float, Integer)).returns(T::Boolean) }
    def expired?(timeout_seconds = 5)
      seconds_since_last_ping > timeout_seconds
    end

    sig { returns(Float) }
    def seconds_since_last_ping
      Time.now.to_f - last_ping_at
    end

    sig do
      params(
        environment: Environment,
        path: String,
        vtree: T.nilable(VDOM::VTree),
        store: T.nilable(State::Store)
      ).void
    end
    def initialize(environment:, path:, vtree: nil, store: nil)
      @environment = environment
      @id = T.let(Nanoid.generate, String)
      @token = T.let(self.class.generate_token, String)
      @path = path
      @vtree = T.let(vtree || VDOM::VTree.new(session: self), VDOM::VTree)
      @store =
        T.let(
          store || environment.create_store(initial_state: {}),
          State::Store
        )
      @app = T.let(environment.load_root(path), VDOM::Descriptor)
      @last_ping_at = T.let(0.0, Float)
    end

    Writable =
      T.type_alias { T.any(Async::HTTP::Body::Writable, Brotli::Writer) }

    sig do
      params(body: Writable, task: Async::Task).returns(
        { stylesheets: T::Array[String] }
      )
    end
    def initial_render(body, task: Async::Task.current)
      @vtree.render(@app, lifecycles: false)

      root = @vtree.root or raise "There is no root"

      html = root.to_html
      stylesheets =
        @vtree
          .assets
          .select { _1.end_with?(".css") }
          .map { "/__mayu/static/#{_1}" }

      freeze

      encrypted_session =
        @environment.message_cipher.dump(
          Marshal.dump(SerializedSession.new(marshal_dump))
        )

      links = [
        %{<script type="module" src="/__mayu/static/#{environment.init_js}" crossorigin="anonymous"></script>},
        *stylesheets.map do |stylesheet|
          %{<link rel="stylesheet" href="#{stylesheet}">}
        end
      ].join

      scripts = %{<template id="mayu-init">#{encrypted_session}</template>}
      body.write("<!doctype html>\n")

      task.async do
        @vtree.root&.write_html(body, links:, scripts:)
        body.close
      rescue => e
        p e
      end

      { stylesheets: }
    end

    sig { returns(T::Array[T.untyped]) }
    def marshal_dump
      [
        @id,
        @token,
        @path,
        VDOM::Marshalling.dump(@vtree),
        Marshal.dump(@store.state)
      ]
    end

    class SerializedSession
      extend T::Sig

      sig { returns(T::Array[T.untyped]) }
      attr_reader :data

      sig { params(data: T::Array[T.untyped]).void }
      def initialize(data)
        @data = data
      end

      sig { params(environment: Environment).returns(Session) }
      def to_session(environment)
        session = Session.allocate
        session.instance_variable_set(:@environment, environment)
        session.marshal_load(@data)
        session
      end

      sig { returns(T::Array[T.untyped]) }
      def marshal_dump
        @data
      end

      sig { params(a: T::Array[T.untyped]).void }
      def marshal_load(a)
        @data = a
      end
    end

    sig { params(a: T::Array[T.untyped]).void }
    def marshal_load(a)
      @id, @token, @path, dumped_vtree, state = a
      @vtree = VDOM::Marshalling.restore(dumped_vtree, session: self)
      @store = @environment.create_store(initial_state: Marshal.restore(state))
      @app = @environment.load_root(@path)
      @last_ping_at = Time.now.to_f
    end

    sig do
      params(
        url: String,
        method: Symbol,
        headers: T::Hash[String, String],
        body: T.nilable(String)
      ).returns(Fetch::Response)
    end
    def fetch(url, method: :GET, headers: {}, body: nil)
      @environment.fetch.fetch(url, method:, headers:, body:)
    end

    sig do
      params(callback_id: String, payload: T::Hash[Symbol, T.untyped]).void
    end
    def handle_callback(callback_id, payload = {})
      @last_ping_at = Time.now.to_f
      @vtree.handle_callback(callback_id, payload)
    end

    sig { void }
    def rerender
      @app = @environment.load_root(path)
      @vtree.replace_root(@app)
    end

    sig { params(path: String).void }
    def navigate(path)
      Console.logger.info(self, "navigate: #{path.inspect}")
      @app = @environment.load_root(path)
      @path = path
      @vtree.replace_root(@app)
    end

    sig do
      params(
        task: Async::Task,
        block: T.proc.params(msg: [Symbol, T.untyped]).void
      ).returns(Async::Barrier)
    end
    def run(task: Async::Task.current, &block)
      root = @vtree.root

      raise "No root!" unless root

      barrier = Async::Barrier.new

      barrier.async do |subtask|
        yield [:init, { ids: root.id_tree }]

        root.traverse do |vnode|
          if c = vnode.component
            c.mount
            # @vtree.update_queue.enqueue(vnode)
          end
        end

        @vtree.render(@app, lifecycles: true)

        updater = VDOM::VTree::Updater.new(@vtree)

        updater
          .run(environment.metrics, task: subtask) do |msg|
            case msg
            in [:patch, patches]
              yield [:patch, patches]
            in [:exception, error]
              yield [:exception, error]
            in [:pong, timestamp]
              yield [:pong, timestamp]
            in [:navigate, href]
              navigate(href)
              yield [:navigate, href]
            else
              puts "\e[31mUnknown event: #{msg.inspect}\e[0m"
            end
          end
          .wait

        barrier.stop
      end

      barrier.async do
        loop do
          # puts "keep alive task"
          sleep 1
          yield [:keep_alive, nil]
        end
      ensure
        # puts "Stopped this task"
        barrier.stop
      end

      barrier
    end
  end
end
