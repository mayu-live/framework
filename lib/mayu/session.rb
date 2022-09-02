# typed: strict

require "time"
require_relative "environment"
require_relative "vdom/vtree"
require_relative "vdom/hydration"

module Mayu
  class Session
    extend T::Sig

    sig do
      params(environment: Environment, path: String).returns(T.attached_class)
    end
    def self.init(environment:, path:)
      session = new(environment:, path:)

      session.initial_render => { html:, stylesheets: }

      encrypted_session = environment.message_cipher.dump(session)

      script = <<~EOF
        <script type="module" src="/__mayu/live.js##{encrypted_session}"></script>
      EOF

      style =
        stylesheets
          .map { |stylesheet| %{<link rel="stylesheet" href="#{stylesheet}">} }
          .join

      body =
        html
          .sub(%r{</head>}) { "#{style}#{_1}" }
          .sub(%r{\K</body>}) { "#{script}#{_1}" }
          .prepend("<!doctype html>\n")

      expires = Time.now + 60 * 60
      cookie = [
        "mayu-token=#{session.token}",
        "path=/__mayu/session/#{session.id}/",
        "expires=#{expires.httpdate}",
        "secure",
        "HttpOnly"
      ].join("; ")

      [
        200,
        {
          "content-type" => "text/html; charset=utf-8",
          "set-cookie" => cookie
        },
        [body]
      ]
    end

    sig do
      params(environment: Environment, dumped: String).returns(T.attached_class)
    end
    def self.restore(environment, dumped)
      Marshal.restore(
        ->(obj) do
          case obj
          when self
            obj.instance_variable_set(:@environment, environment)
            obj
          else
            obj
          end
        end
      )
    end

    Marshaled = T.type_alias { [String, String, String, String, String] }

    sig { returns(String) }
    attr_reader :id
    sig { returns(String) }
    attr_reader :token

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
      @id = T.let(SecureRandom.uuid, String)
      @token = T.let(SecureRandom.alphanumeric(64), String)
      @path = path
      @vtree = T.let(vtree || VDOM::VTree.new(session: self), VDOM::VTree)
      @store =
        T.let(
          store || environment.create_store(initial_state: {}),
          State::Store
        )
      @app = T.let(environment.load_root(path), VDOM::Descriptor)
    end

    sig { returns(Marshaled) }
    def marshal_dump
      [
        @id,
        @token,
        @path,
        VDOM::Hydration.dump(@vtree),
        Marshal.dump(@store.state)
      ]
    end

    sig { params(a: Marshaled).void }
    def marshal_load(a)
      @id, @token, @path, dumped_vtree, state = a
      @vtree = VDOM::Hydration.restore(dumped_vtree)
      @store = @environment.create_store(initial_state: state)
      @app = T.let(@environment.load_root(path), VDOM::Descriptor)
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
      params(lifecycles: T::Boolean).returns(
        { html: String, stylesheets: T::Array[String] }
      )
    end
    def initial_render(lifecycles: false)
      @vtree.render(@app, lifecycles:)
      root = @vtree.root
      raise unless root
      html = root.to_html
      stylesheets = []
      { html:, stylesheets: }
    end

    sig do
      params(block: T.proc.params(msg: [Symbol, T.untyped]).void).returns(
        Async::Task
      )
    end
    def run(&block)
      root = @vtree.root

      raise "No root!" unless root

      yield [:init, { ids: root.id_tree }]

      root.traverse do |vnode|
        if c = vnode.component
          c.mount
          # @vtree.update_queue.enqueue(vnode)
        end
      end

      @vtree.render(@app, lifecycles: true)

      updater = VDOM::VTree::Updater.new(@vtree)

      updater.run do |msg|
        case msg
        in [:patch, patches]
          yield [:patch, patches]
        in [:exception, error]
          yield [:exception, error]
        in [:navigate, href]
          navigate(href)
          yield [:navigate, href]
        else
          puts "\e[31mUnknown event: #{msg.inspect}\e[0m"
        end
      end
    end
  end
end
