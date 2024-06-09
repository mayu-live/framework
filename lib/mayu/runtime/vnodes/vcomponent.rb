# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "async/barrier"
require_relative "base"

module Mayu
  module Runtime
    module VNodes
      class VComponent < Base
        class Context
          def initialize(parent: nil)
            @vars = {}
            @parent = parent
            @notification = Async::Notification.new
          end

          attr_reader :parent

          def [](var)
            @vars.fetch(var) { @parent[var] if parent }
          end

          def []=(var, value)
            return if @vars[var] == value
            @vars[var] = value
            @notification.signal(var)
          end

          def wait
            @notification.wait
          end

          def marshal_dump
            [@vars, @parent]
          end

          def marshal_load(a)
            @vars, @parent = a
            @notification = Async::Notification.new
          end
        end

        def initialize(...)
          super
          klass = @descriptor.type

          if mod = get_mod
            mod.assets.each do |filename|
              if filename.end_with?(".css")
                closest(VDocument).add_stylesheet(filename)
              end
            end
          end

          @context = Context.new(parent: @parent.closest(self.class)&.context)

          @instance = klass.allocate

          @instance.instance_variable_set(:@__props, @descriptor.props.freeze)
          @instance.instance_variable_set(:@__context, @context)
          @instance.instance_variable_set(
            :@__children,
            @descriptor.children.freeze
          )

          @instance.send(:initialize)
          @children = VChildren.new(render_children, parent: self)
        end

        attr_reader :context

        def marshal_dump
          [super, @instance, @children, @context]
        end

        def marshal_load(a)
          a => [a, instance, children, context]
          super(a)
          @instance = instance
          @children = children
          @context = context
        end

        def traverse(&)
          yield self
          @children.traverse(&)
        end

        def insert = @children.insert
        def render = @children.render
        def remove = @children.remove
        def child_ids = @children.child_ids

        def update_sync(descriptor)
          @descriptor = descriptor

          old_props = @instance.instance_variable_get(:@__props)
          old_children = @instance.instance_variable_get(:@__children)

          @instance.instance_variable_set(
            :@__children,
            @descriptor.children.freeze
          )
          @instance.instance_variable_set(:@__props, @descriptor.props.freeze)

          @children.update(render_children)
        end

        def start_children
          Async do
            barrier = Async::Barrier.new
            queue = Async::Queue.new

            @instance.define_singleton_method(:rerender!) do
              queue.enqueue(:rerender)
            end

            barrier.async do
              while x = queue.dequeue
                @children.update(render_children) if x == :rerender
              end
            end

            barrier.async do
              loop do
                @context.wait
                queue.enqueue(:rerender)
              end
            end

            barrier.async do
              # puts "\e[1mMounting #{component_type_name}\e[0m"

              handle_errors { @instance.mount }
            end

            barrier.async { @children.start }

            barrier.wait
          ensure
            barrier.stop
            puts "\e[2mUnmounting #{component_type_name}\e[0m"
            @instance.unmount
          end
        end

        private

        def handle_errors
          yield
        rescue => e
          mod = get_mod
          raise unless mod

          puts mod.source_map.format_exception(e, mod.path)

          patch(
            Patches::RenderError[
              mod.path,
              e.class.name,
              e.message,
              e.backtrace,
              mod.source_map.input,
              []
            ]
          )

          nil
        end

        def render_children
          handle_errors { @instance.render }
        end

        def get_mod
          if module_path = @descriptor.type.module_path
            Modules::System.current.get_mod(module_path)
          end
        end

        def component_type_name
          klass = @instance.class

          name = (klass.module_path if klass.respond_to?(:module_path)).to_s

          name.empty? ? klass.name : name
        end
      end
    end
  end
end
