# typed: strict

require "bundler/setup"
require "sorbet-runtime"
require_relative "descriptor_builder"

module Mayu
  module Markup
    class RenderContext < BasicObject
      extend ::T::Sig

      sig {params(fiber: ::Fiber, real_self: ::T.untyped).void}
      def initialize(fiber, real_self)
        @__fiber = fiber
        @__real_self = real_self

        # Copy instance variables from the object where we were.
        instance_variable_set =
          ::Object.instance_method(:instance_variable_set).bind(self)

        real_self.instance_variables.each do |var|
          instance_variable_set.call(var, real_self.instance_variable_get(var))
        end
      end

      sig{params(method: ::Symbol, args: ::T.untyped, kwargs: ::T.untyped, block: ::T.untyped).returns(::T.untyped)}
      def method_missing(method, *args, **kwargs, &block)
        @__real_self.send(method, *args, **kwargs, &block)
      end

      sig{returns(::Mayu::Markup::Builder)}
      def h
        ::Mayu::Markup::Builder.new(@__fiber)
      end

      sig{returns(String)}
      def to_s
        inspect
      end

      sig{returns(String)}
      def inspect
        "#<RenderContext real_self=#{@__real_self}>"
      end
    end

    class Builder
      extend T::Sig

      class NestingError < StandardError
      end

      include Generated::DescriptorBuilders

      sig { params(parent_fiber: T.nilable(Fiber)).void }
      def initialize(parent_fiber = nil)
        @parent_fiber = parent_fiber
      end

      sig {params(descriptor_or_text: T.untyped).returns(VDOM::Descriptor)}
      def <<(descriptor_or_text)
        descriptor = VDOM::Descriptor.or_text(descriptor_or_text)
        @parent_fiber&.resume([:append, descriptor])
        descriptor
      end

      sig{params(component: VDOM::Descriptor::ComponentType, children: VDOM::Descriptor::ChildType, props: T.untyped, block: T.nilable(T.proc.void)).returns(VDOM::Descriptor)}
      def [](component, *children, **props, &block)
        create_element(component, children, props, &block)
      end

      sig{override.params(type: VDOM::Descriptor::ElementType, children: T::Array[VDOM::Descriptor::ChildType], props: T::Hash[Symbol, T.untyped], block: T.nilable(T.proc.void)).returns(VDOM::Descriptor)}
      def create_element(type, children, props, &block)
        @parent_fiber&.resume([:open, type])
        capture_children(children, &block) if block
        descriptor = VDOM::Descriptor.new(type, props, children)
        @parent_fiber&.resume([:close, descriptor])
        descriptor
      end

      private

      sig{params(children: T::Array[VDOM::Descriptor::ChildType], block: T.proc.void).void}
      def capture_children(children, &block)
        fiber =
          Fiber.new do |msg|
            catch :terminate do
                opened = T.let(nil, T.nilable(VDOM::Descriptor::ElementType))

              loop do
                case msg
                in :terminate
                  throw :terminate
                in [:append, descriptor]
                  raise NestingError, "#{opened} has not been closed" if opened
                  children.push(descriptor)
                in [:open, element]
                  #$logger.info "Opening #{element}"
                  opened = element
                in [:close, descriptor]
                  # unless opened == descriptor.type
                  #   raise NestingError,
                  #         "Closing a #{descriptor.type.inspect} but expected #{opened.inspect}"
                  # end

                  #$logger.info "Closing #{descriptor.type}"
                  opened = nil
                  children.push(descriptor)
                end

                msg = Fiber.yield
              end
            end
          end

        # Get the previous self from the binding so that the RenderContext
        # object can delegate to it with method_missing..
        previous_self = eval("self", block.binding)
        RenderContext.new(fiber, previous_self).instance_eval(&block)

        fiber.resume(:terminate)
      end
    end
  end
end
