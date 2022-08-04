# typed: strict

require_relative "h"
require_relative "../modules/css"
require "async/barrier"

module Mayu
  module VDOM
    module Component
      extend T::Sig

      Props = T.type_alias { T::Hash[Symbol, T.untyped] }
      State = T.type_alias { T::Hash[String, T.untyped] }

      sig do
        params(
          vnode: VNode,
          type: T.untyped,
          props: Props,
          task: Async::Task
        ).returns(T.nilable(Wrapper))
      end
      def self.wrap(vnode, type, props, task: Async::Task.current)
        if type.is_a?(Class) && type < Component::Base
          Wrapper.new(vnode, type, props, task:)
        else
          nil
        end
      end

      module Interface
        extend T::Sig
        extend T::Helpers
        interface!

        sig { abstract.params(props: Props, state: State).returns(T::Boolean) }
        def should_update?(props, state)
        end

        sig { abstract.returns(T.any(T.nilable(Descriptor), [Descriptor])) }
        def render
        end

        sig { abstract.void }
        def mount
        end
        sig { abstract.void }
        def unmount
        end

        sig { abstract.params(prev_props: Props, prev_state: State).void }
        def did_update(prev_props, prev_state)
        end
      end

      class Wrapper
        extend T::Sig
        include Interface

        sig {returns(T.nilable(Modules::CSS::CSSModule))}
        def stylesheet
          if stylesheet = @instance.class.stylesheets
            if stylesheet.is_a?(Modules::CSS::CSSModule)
              stylesheet
            end
          end
        end

        sig { returns(State) }
        attr_accessor :state
        sig { returns(State) }
        attr_accessor :next_state
        sig { returns(Props) }
        attr_accessor :props

        sig { returns(T::Boolean) }
        def dirty? = @dirty
        sig { returns(TrueClass) }
        def dirty! = @dirty = true

        sig { returns(Base) }
        attr_reader :instance

        sig do
          params(
            vnode: VNode,
            klass: T.class_of(Base),
            props: Props,
            task: Async::Task
          ).void
        end
        def initialize(vnode, klass, props, task: Async::Task.current)
          @vnode = vnode
          @props = T.let(props, Props)
          @state = T.let(klass.get_initial_state(props).freeze, State)
          @next_state = T.let(@state.clone, State)
          @instance = T.let(klass.new(self), Base)
          @dirty = T.let(true, T::Boolean)
          @barrier = T.let(Async::Barrier.new(parent: task), Async::Barrier)
        end

        sig do
          override
            .params(next_props: Props, next_state: State)
            .returns(T::Boolean)
        end
        def should_update?(next_props, next_state)
          wrap_errors { @instance.should_update?(next_props, next_state) }
        end

        sig { override.returns(T.any(T.nilable(Descriptor), [Descriptor])) }
        def render
          wrap_errors { @instance.render }
        ensure
          @dirty = false
        end

        sig { override.void }
        def mount
          wrap_errors { async { @instance.mount } }
        end

        sig { override.void }
        def unmount
          wrap_errors { @instance.unmount }
          @barrier.stop
        end

        sig { override.params(prev_props: Props, prev_state: State).void }
        def did_update(prev_props, prev_state)
          wrap_errors { @instance.did_update(prev_props, prev_state) }
        end

        sig { params(blk: T.proc.void).void }
        def async(&blk)
          @barrier.async(&blk)
        end

        sig { params(path: String).void }
        def navigate(path)
          @vnode.navigate(path)
        end

        sig do
          params(
            stuff: T.nilable(State),
            blk: T.nilable(T.proc.params(arg0: State).returns(State))
          ).void
        end
        def update(stuff = nil, &blk)
          stuff = blk.call(state) if blk

          # puts "Merging stuff, #{stuff.inspect}"

          if stuff
            @next_state = @next_state.merge(stuff)

            enqueue_update!
          end
        end

        private

        sig do
          type_parameters(:R)
            .params(blk: T.proc.returns(T.type_parameter(:R)))
            .returns(T.type_parameter(:R))
        end
        def wrap_errors(&blk)
          yield
        rescue StandardError
          # TODO: Do some sourcemap magic here maybe, idk.
          raise
        end

        sig { void }
        def enqueue_update!
          @vnode.enqueue_update!
        end
      end

      class Base
        extend T::Sig
        include Interface
        include VDOM::H

        sig { params(path: String).returns(T.class_of(Component::Base)) }
        def self.import(path)
          case const_get(:MAYU_MODULE)
          in { system: system, path: self_path }
            cm = system.load_component(path, self_path)
            cm.klass
          else
            raise "wtf"
          end
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
          params(blk: T.proc.returns(T.nilable(Descriptor::Children))).void
        end
        def self.render(&blk) = define_method(:render, &blk)

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
      end

      sig { params(klass: T.untyped).returns(T::Boolean) }
      def self.component_class?(klass)
        !!(klass.is_a?(Class) && klass < Base)
      end

      class HandlerRef
        extend T::Sig

        sig { returns(String) }
        attr_reader :id

        sig do
          params(
            component: Component::Base,
            name: Symbol,
            args: T::Array[T.untyped],
            kwargs: T::Hash[Symbol, T.untyped],
          ).void
        end
        def initialize(component, name, args = [], kwargs = {})
          @component = component
          @name = name
          @args = args
          @kwargs = kwargs
          @id =
            T.let(
              Digest::SHA256.hexdigest(
                [@component.object_id, @name, @args, @kwargs].map(&:inspect).join(":")
              ),
              String
            )
        end

        sig { params(payload: T.untyped).void }
        def call(payload)
          method = @component.method(:"handle_#{@name}")
          T.unsafe(method).call(*[payload, *@args, **@kwargs].first(method.arity))
        end

        sig { returns(String) }
        def to_s
          "Mayu.handle(event,'#{@id}')"
        end

        sig { params(other: HandlerRef).returns(T::Boolean) }
        def ==(other)
          @id == other.id
        end
      end

      module Hax
        class HeadComponent < Component::Base
          sig { override.returns(T.nilable(Descriptor)) }
          def render
            h(:__mayu_head, **props) do
              [
                children
                #h(:link, rel: "stylesheet", href: "/foo.css")
              ].flatten.compact
            end
          end
        end

        class BodyComponent < Component::Base
          sig { override.returns(T.nilable(Descriptor)) }
          def render
            h(:__mayu_body, **props) { children }
          end
        end

        class AComponent < Component::Base
          handler(:click) do |_event, href|
            navigate(href.to_s)
          end

          sig { override.returns(T.nilable(Descriptor)) }
          def render
            h(:__mayu_a, **props.merge(on_click: handler(:click, props[:href]))) { children }
          end
        end
      end
    end
  end
end
