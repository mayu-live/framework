# typed: strict

require_relative "vdom"
require_relative "vdom/vtree"
require_relative "vdom/component"
require_relative "modules/system"
require_relative "routes"
require_relative "session"

module Mayu
  class Renderer
    extend T::Sig

    sig do
      params(
        environment: Environment,
        request_path: String,
        app: VDOM::Descriptor,
        parent: T.any(Async::Task, Async::Barrier)
      ).void
    end
    def initialize(
      environment:,
      request_path:,
      app: environment.load_root(request_path),
      parent: Async::Task.current
    )
      @environment = environment
      @session = T.let(Session.new(environment, request_path:), Session)
      @app = app

      # Set up a barrier to group async tasks together.
      @barrier = T.let(Async::Barrier.new(parent:), Async::Barrier)

      @vtree =
        T.let(VDOM::VTree.new(session: @session, task: @barrier), VDOM::VTree)

      if code_reloader = environment.modules.code_reloader
        @barrier.async do
          code_reloader.on_update { navigate(@session.current_path) }
        end
      end
    end

    sig do
      returns({ html: String, ids: T.untyped, stylesheets: T::Array[String] })
    end
    def initial_render
      render!
      root = @vtree.root
      raise unless root
      html = root.to_html
      ids = root.id_tree
      stylesheets = []
      { html:, ids:, stylesheets: }
    end

    sig do
      params(block: T.proc.params(msg: [Symbol, T.untyped]).void).returns(
        Async::Task
      )
    end
    def run(&block)
      updater = VDOM::VTree::Updater.new(@vtree)
      puts "STARTING RUN"

      updater.run do |msg|
        Console.logger.warn(msg.inspect)
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

    sig { params(callback_id: String, payload: T.untyped).returns(T::Boolean) }
    def handle_callback(callback_id, payload = {})
      @vtree.handle_callback(callback_id, payload)
      true
    end

    sig { returns(T::Boolean) }
    def running? = @barrier.empty?

    sig { void }
    def stop
      # @vtree.stop!
      @barrier.stop
    end

    sig { returns(T.untyped) }
    def id_tree = @vtree.id_tree

    private

    sig { params(path: String).void }
    def navigate(path)
      @session.navigate(path)
      render!
    end

    sig { returns(VDOM::UpdateContext) }
    def render!
      @vtree.render(@app)
    end
  end
end
