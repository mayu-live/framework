# typed: strict

require_relative "../component"
require_relative "interface"
require_relative "wrapper"
require_relative "handler_ref"

module Mayu
  module VDOM
    module Component
      class Base
        extend T::Sig
        include Interface
        include VDOM::H

        sig { params(component_path: String).returns(T.class_of(Component::Base)) }
        def self.import(component_path)
          const_get(:MAYU_MODULE) => { system:, path:, full_path: }
          cm = system.load_component(component_path, path)
          system.add_dependency(full_path, cm.klass.const_get(:MAYU_MODULE)[:full_path])
          cm.klass
        end

        sig {returns(String)}
        def inspect
          self.class.const_get(:MAYU_MODULE).fetch(:path, "unknown path")
        end

        sig { returns(Props) }
        def props = @wrapper.props
        sig { returns(State) }
        def state = @wrapper.state

        sig { params(wrapper: Wrapper).void }
        def initialize(wrapper)
          @wrapper = T.let(wrapper, Wrapper)
        end

        sig { params(props: Props).returns(State) }
        def self.get_initial_state(props) = {}

        sig do
          # params(blk: T.proc.returns(T.nilable(Descriptor::Children))).void
          params(blk: T.proc.void).void
        end
        def self.render(&blk)
          define_method :render, &blk
        end

        # sig {returns(Markup::Builder)}
        # def h = Markup::Builder.new

        sig { params(blk: T.proc.params(arg0: Props).returns(State)).void }
        def self.initial_state(&blk) =
          define_singleton_method(:get_initial_state, &blk)

        sig { params(name: Symbol, blk: T.proc.bind(T.attached_class).void).void }
        def self.handler(name, &blk) = define_method(:"handle_#{name}", &blk)

        sig do
          params(
            blk:
              T
                .proc
                .params(next_props: Props, next_state: State)
                .returns(T::Boolean)
          ).void
        end

        def self.should_update?(&blk) = define_method(:should_update?, &blk)

        sig { params(blk: T.proc.void).void }
        def self.mount(&blk) = define_method(:mount, &blk)
        sig { params(blk: T.proc.void).void }
        def self.unmount(&blk) = define_method(:unmount, &blk)

        sig { params(blk: T.proc.void).void }
        def async(&blk) = @wrapper.async(&blk)

        sig { params(url: String, method: Symbol, headers: T::Hash[String, String], body: T.nilable(String)).returns(Fetch::Response) }
        def fetch(url, method: :GET, headers: {}, body: nil)
          @wrapper.fetch(url, method:, headers:, body:)
        end

        sig { override.void }
        def mount = nil
        sig { override.void }
        def unmount = nil

        sig do
          override
            .params(next_props: Props, next_state: State)
            .returns(T::Boolean)
        end
        def should_update?(next_props, next_state)
          # p [props, next_props]
          # p [state, next_state]
          case
          when props != next_props
            true
          when state != next_state
            true
          else
            false
          end
        end

        sig { override.returns(T.nilable(Descriptor)) }
        def render = nil
        sig { override.params(prev_props: Props, prev_state: State).void }
        def did_update(prev_props, prev_state) = nil

        sig { returns(Modules::CSS::Base) }
        def self.stylesheets
          begin
            const_get(:CSS)
          rescue StandardError
            Modules::CSS::NoModule.new("asd")
          end
        end

        sig { returns(Modules::CSS::IdentProxy) }
        def self.styles = stylesheets.proxy

        sig { returns(Modules::CSS::IdentProxy) }
        def styles = self.class.styles

        sig { returns(Descriptor::Children) }
        def children = props[:children]

        sig do
          params(
            stuff: T.nilable(State),
            blk: T.nilable(T.proc.params(arg0: State).returns(State))
          ).void
        end
        def update(stuff = nil, &blk)
          @wrapper.update(stuff, &blk)
        end

        sig { params(name: Symbol, args: T.untyped, kwargs: T.untyped).returns(HandlerRef) }
        def handler(name, *args, **kwargs)
          HandlerRef.new(self, name, args, kwargs)
        end

        sig { params(path: String).void }
        def navigate(path)
          @wrapper.navigate(path)
        end

        sig { params(klass: T.untyped).returns(T::Boolean) }
        def self.component_class?(klass)
          !!(klass.is_a?(Class) && klass < Base)
        end
      end
    end
  end
end
