# typed: strict

require "async/barrier"
require_relative "../component"
require_relative "interface"
require_relative "base"

module Mayu
  module VDOM
    module Component
      class Wrapper
        extend T::Sig
        include Component::Interface

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

        sig { params(url: String, method: Symbol, headers: T::Hash[String, String], body: T.nilable(String)).returns(Fetch::Response) }
        def fetch(url, method: :GET, headers: {}, body: nil)
          @vnode.fetch(url, method:, headers:, body:)
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
    end
  end
end
