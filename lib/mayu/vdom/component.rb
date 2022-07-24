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
          @state = T.let({}, State)
          @next_state = T.let({}, State)
          @props = T.let(props, Props)
          @instance = T.let(klass.new(self), Base)
          @dirty = T.let(true, T::Boolean)
        end

        sig {override.params(new_props: Props, new_state: State).returns(T::Boolean)}
        def should_update?(new_props, new_state)
          wrap_errors { @instance.should_update?(new_props, new_state) }
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

        sig {params(update: T.nilable(State), blk: T.nilable(T.proc.params(arg0: State).returns(State))).void}
        def update_state(update = nil, &blk)
          if blk
            update = blk.call(state)
          end

          if update
            @next_state.merge!(update)

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

        sig {params(blk: T.proc.returns(T.nilable(Descriptor::Children))).void}
        def self.render(&blk) = define_method(:render, &blk)
        sig {params(blk: T.proc.params(arg0: Props).returns(State)).void}
        def self.initial_state(&blk) = define_method(:initial_state, &blk)
        sig {params(name: Symbol, blk: T.proc.returns(State)).void}
        def self.handler(name, &blk) = define_method(:"#{name}_name", &blk)
        sig {params(blk: T.proc.params(new_props: Props, new_state: State).returns(T::Boolean)).void}
        def self.should_update?(&blk) = define_method(:should_update?, &blk)

        sig {override.void}
        def did_mount = nil
        sig {override.void}
        def will_unmount = nil
        sig {override.params(new_props: Props, new_state: State).returns(T::Boolean)}
        def should_update?(new_props, new_state)
          props != new_props || state != new_state
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

        sig {params(name: Symbol, args: T.nilable(T::Array[T.untyped])).returns(HandlerRef)}
        def handler(name, *args)
          HandlerRef.new(self, name, args)
        end
      end

      sig {params(klass: T.untyped).returns(T::Boolean)}
      def self.component_class?(klass)
        !!(klass.is_a?(Class) && klass < Base)
      end
    end

    class HandlerRef
      extend T::Sig

      sig {params(component: Component::Base, name: Symbol, args: T::Array[T.untyped]).void}
      def initialize(component, name, args = [])
        @component = component
        @name = name
        @args = args
      end

      sig {params(data: T.untyped).void}
      def call(data)
        @component.send(:"handle_#{@name}")
      end

      sig {returns(String)}
      def to_s
        id = Digest::SHA256.hexdigest([@component.object_id, @name, @args].map(&:inspect).join(":"))
        "Mayu.handle(event, '#{id}')"
      end
    end
  end
end
