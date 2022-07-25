# typed: strict

require_relative "h"
require_relative "../modules/css_module"

module Mayu
  module VDOM
    module Component
      extend T::Sig

      Props = T.type_alias { T::Hash[Symbol, T.untyped] }
      State = T.type_alias { T::Hash[String, T.untyped] }

      sig {params(vnode: VNode, type: T.untyped, props: Props).returns(T.nilable(Wrapper))}
      def self.wrap(vnode, type, props)
        if type.is_a?(Class) && type < Component::Base
          Wrapper.new(vnode, type, props)
        else
          nil
        end
      end

      module Interface
        extend T::Sig
        extend T::Helpers
        interface!

        sig {abstract.params(props: Props, state: State).returns(T::Boolean)}
        def should_update?(props, state); end

        sig {abstract.returns(T.nilable(Descriptor::Children))}
        def render; end

        sig {abstract.void}
        def did_mount; end
        sig {abstract.void}
        def will_unmount; end

        sig {abstract.params(prev_props: Props, prev_state: State).void}
        def did_update(prev_props, prev_state); end
      end

      class Wrapper
        extend T::Sig
        include Interface

        sig {returns(State)}
        attr_accessor :state
        sig {returns(State)}
        attr_accessor :next_state
        sig {returns(Props)}
        attr_accessor :props

        sig {returns(T::Boolean)}
        def dirty? = @dirty
        sig {returns(TrueClass)}
        def dirty! = @dirty = true

        sig {params(vnode: VNode, klass: T.class_of(Base), props: Props).void}
        def initialize(vnode, klass, props)
          @vnode = vnode
          @props = T.let(props, Props)
          @state = T.let(klass.get_initial_state(props), State)
          @next_state = T.let({}.merge(@state), State)
          @instance = T.let(klass.new(self), Base)
          @dirty = T.let(true, T::Boolean)
        end

        sig {override.params(next_props: Props, next_state: State).returns(T::Boolean)}
        def should_update?(next_props, next_state)
          wrap_errors { @instance.should_update?(next_props, next_state) }
        end

        sig {override.returns(T.nilable(Descriptor::Children))}
        def render
          wrap_errors { @instance.render }
        ensure
          @dirty = false
        end

        sig {override.void}
        def did_mount
          wrap_errors { @instance.did_mount }
        end
        sig {override.void}
        def will_unmount
          wrap_errors { @instance.will_unmount }
        end

        sig {override.params(prev_props: Props, prev_state: State).void}
        def did_update(prev_props, prev_state)
          wrap_errors { @instance.did_update(prev_props, prev_state) }
        end

        sig {params(stuff: T.nilable(State), blk: T.nilable(T.proc.params(arg0: State).returns(State))).void}
        def update(stuff = nil, &blk)
          if blk
            stuff = blk.call(state)
          end

          puts "Merging stuff, #{stuff.inspect}"

          if stuff
            @next_state = @next_state.merge(stuff)

            enqueue_update!
          end
        end

        private

        sig {
          type_parameters(:R)
            .params(blk: T.proc.returns(T.type_parameter(:R)))
            .returns(T.type_parameter(:R))
        }
        def wrap_errors(&blk)
          yield
        rescue
          # TODO: Do some sourcemap magic here maybe, idk.
          raise
        end

        sig {void}
        def enqueue_update!
          @vnode.enqueue_update!
        end
      end

      class Base
        extend T::Sig
        include Interface
        include VDOM::H

        sig {params(path: String).returns(T.class_of(Component::Base))}
        def self.import(path)
          case const_get(:MAYU_MODULE)
          in { system: system, path: self_path  }
            cm = system.load_component(path, self_path)
            cm.klass
          else
            raise "wtf"
          end
        end

        sig {returns(Props)}
        def props() = @wrapper.props
        sig {returns(State)}
        def state() = @wrapper.state

        sig {params(wrapper: Wrapper).void}
        def initialize(wrapper)
          @wrapper = T.let(wrapper, Wrapper)
        end

        sig {params(props: Props).returns(State)}
        def self.get_initial_state(props) = {}

        sig {params(blk: T.proc.returns(T.nilable(Descriptor::Children))).void}
        def self.render(&blk) = define_method(:render, &blk)
        sig {params(blk: T.proc.params(arg0: Props).returns(State)).void}
        def self.initial_state(&blk) = define_singleton_method(:get_initial_state, &blk)
        sig {params(name: Symbol, blk: T.proc.returns(State)).void}
        def self.handler(name, &blk) = define_method(:"handle_#{name}", &blk)
        sig {params(blk: T.proc.params(next_props: Props, next_state: State).returns(T::Boolean)).void}
        def self.should_update?(&blk) = define_method(:should_update?, &blk)

        sig {override.void}
        def did_mount = nil
        sig {override.void}
        def will_unmount = nil
        sig {override.params(next_props: Props, next_state: State).returns(T::Boolean)}
        def should_update?(next_props, next_state)
          case
          when props != next_props
            true
          when state != next_state
            true
          else
            false
          end
        end

        sig {override.returns(T.nilable(Descriptor::Children))}
        def render = nil
        sig {override.params(prev_props: Props, prev_state: State).void}
        def did_update(prev_props, prev_state) = nil

        sig {returns(Modules::CSSModule::IdentProxy)}
        def self.styles = const_get(:CSS).proxy

        sig {returns(Modules::CSSModule::IdentProxy)}
        def styles = self.class.styles

        sig {returns(Descriptor::Children)}
        def children = props[:children]

        sig {params(stuff: T.nilable(State), blk: T.nilable(T.proc.params(arg0: State).returns(State))).void}
        def update(stuff = nil, &blk)
          @wrapper.update(stuff, &blk)
        end

        sig {params(name: Symbol, args: T.untyped).returns(HandlerRef)}
        def handler(name, *args)
          HandlerRef.new(self, name, args)
        end
      end

      sig {params(klass: T.untyped).returns(T::Boolean)}
      def self.component_class?(klass)
        !!(klass.is_a?(Class) && klass < Base)
      end

      class HandlerRef
        extend T::Sig

        sig {returns(String)}
        attr_reader :id

        sig {params(component: Component::Base, name: Symbol, args: T::Array[T.untyped]).void}
        def initialize(component, name, args = [])
          @component = component
          @name = name
          @args = args
          @id = T.let(
            Digest::SHA256.hexdigest([
              @component.object_id,
              @name,
              @args,
            ].map(&:inspect).join(":")),
            String
          )
        end

        sig {params(payload: T.untyped).void}
        def call(payload)
          T.unsafe(@component.method(:"handle_#{@name}")).call(payload, *@args)
        end

        sig {returns(String)}
        def to_s
          "Mayu.handle(event,'#{@id}')"
        end
      end

      module Hax
        class HeadComponent < Component::Base
          sig {override.returns(T.nilable(Descriptor::Children))}
          def render
            h(:__mayu_head, **props) do
              [
                children,
                h(:link, rel: "stylesheet", href: "/foo.css")
              ].flatten.compact
            end
          end
        end

        class BodyComponent < Component::Base
          sig {override.returns(T.nilable(Descriptor::Children))}
          def render
            h(:__mayu_body, **props) do
              children
            end
          end
        end
      end
    end
  end
end
