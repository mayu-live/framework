# typed: strict

require "async/queue"
require "nanoid"
require "benchmark"
require_relative "../component"
require_relative "interfaces"
require_relative "descriptor"
require_relative "dom"
require_relative "vnode"
require_relative "css_attributes"
require_relative "update_context"
require_relative "id_generator"
require_relative "../session"
require_relative "../ref_counter"
require_relative "../utils"
require_relative "./reconciliation"

module Mayu
  module VDOM
    class VTree
      extend T::Sig

      include Interfaces::VTree

      class Updater
        extend T::Sig

        # This value limits how many updates per second we can make.
        DEFAULT_UPDATES_PER_SECOND = 20

        sig { params(vtree: VTree, updates_per_second: Integer).void }
        def initialize(vtree, updates_per_second: DEFAULT_UPDATES_PER_SECOND)
          @vtree = vtree
          @updates_per_second = updates_per_second
        end

        sig do
          params(
            metrics: T.nilable(AppMetrics),
            task: Async::Task,
            block: T.proc.params(arg0: [Symbol, T.untyped]).void
          ).returns(Async::Task)
        end
        def run(metrics: nil, task: Async::Task.current, &block)
          task.async(annotation: "VTree updater") do |task|
            assets = T::Set[String].new

            loop do
              @vtree.update_queue.wait while @vtree.update_queue.empty?

              start_at = Time.now

              update(assets:, metrics:) do |event, payload|
                yield [event, payload]
              end

              delta_time_ms = (Time.now - start_at) * 1000

              # TODO: Make this configurable..
              # should also be in the prometheus output
              if delta_time_ms > 50
                Console.logger.warn(
                  self,
                  "Rendering took %.3fms" % delta_time_ms
                )
              end

              yield [:update_finished, delta_time_ms:]

              sleep 1.0 / @updates_per_second
            end
          rescue => e
            puts e.message
            puts e.backtrace
            error = {
              type: e.class.name,
              message: e.message,
              backtrace: e.backtrace
            }

            yield [:exception, error]
          end
        end

        sig do
          params(stylesheets: T::Array[String]).returns(T::Array[T.untyped])
        end
        def stylesheet_patch(stylesheets)
          return [] if stylesheets.empty?

          paths = stylesheets.map { "/__mayu/static/#{_1}" }

          [{ type: :stylesheet, paths: }]
        end

        sig do
          params(
            assets: T::Set[String],
            metrics: T.nilable(AppMetrics),
            block: T.proc.params(arg0: [Symbol, T.untyped]).void
          ).void
        end
        def update(assets: T::Set[String].new, metrics: nil, &block)
          ctx = UpdateContext.new

          @vtree.update_queue.size.times do
            case @vtree.update_queue.dequeue
            in [:replace_root, descriptor]
              @vtree.render(descriptor, ctx:)
            in [:navigate, path]
              yield [:navigate, path]
            in [:action, payload]
              yield [:action, payload]
            in [:exception, error]
              yield [:exception, error]
            in [:pong, timestamp]
              yield [:pong, timestamp]
            in VNode => vnode
              next if vnode.removed?
              next unless vnode.component&.dirty?

              if metrics
                type = vnode.descriptor.type
                vnode_type =
                  if type.respond_to?(:__mayu_resource) &&
                       resource = type.__mayu_resource
                    resource.path
                  else
                    type.inspect[0..10].to_s
                  end

                metrics.vnode_patch_times.observe(
                  Benchmark.realtime do
                    @vtree.patch(ctx, vnode, vnode.descriptor, lifecycles: true)
                  end,
                  labels: {
                    vnode_type:
                  }
                )
              else
                @vtree.patch(ctx, vnode, vnode.descriptor, lifecycles: true)
              end
            end
          end

          stylesheets = []

          @vtree.assets.each do |asset|
            next if assets.include?(asset)
            next unless asset.end_with?(".css")
            stylesheets.push(asset)
            assets.add(asset)
          end

          patches = [*stylesheet_patch(stylesheets), *ctx.patches]
          yield [:patch, patches] unless patches.empty?

          @vtree.cleanup_unused_handlers!
        end
      end

      sig { override.returns(Session) }
      attr_reader :session

      sig { returns(Async::Queue) }
      attr_reader :update_queue
      sig { returns(T.nilable(VNode)) }
      attr_reader :root

      sig { returns(T::Set[String]) }
      attr_reader :assets

      sig { params(session: Session, task: Async::Task).void }
      def initialize(session:, task: Async::Task.current)
        @root = T.let(nil, T.nilable(VNode))
        @id_generator = T.let(IdGenerator.new, IdGenerator)
        @session = T.let(session, Session)

        @handlers = T.let({}, T::Hash[String, Component::HandlerRef])
        @handler_counts = T.let(RefCounter.new, RefCounter[String])

        @update_queue = T.let(Async::Queue.new, Async::Queue)

        @update_semaphore =
          T.let(Async::Semaphore.new(parent: task), Async::Semaphore)

        @assets = T.let(Set.new, T::Set[String])
      end

      sig { returns(T::Array[T.untyped]) }
      def marshal_dump
        [@root, @id_generator, @assets]
      end

      sig { params(a: T::Array[T.untyped]).void }
      def marshal_load(a)
        @root, @id_generator, @assets = a
        @handlers = {}
        @handler_counts = RefCounter.new
        @update_queue = Async::Queue.new
        @update_semaphore = Async::Semaphore.new
        @assets = Set.new
        @root.instance_variable_set(:@vtree, self)
      end

      sig do
        params(
          descriptor: Interfaces::Descriptor,
          ctx: UpdateContext,
          lifecycles: T::Boolean
        ).returns(UpdateContext)
      end
      def render(descriptor, ctx: UpdateContext.new, lifecycles: true)
        start_at = Time.now
        @root = patch(ctx, @root, descriptor, lifecycles:)
        ctx
      end

      sig { params(descriptor: Interfaces::Descriptor).void }
      def replace_root(descriptor)
        @update_queue.enqueue([:replace_root, descriptor])
      end

      sig { params(handler_id: String, payload: T.untyped).void }
      def handle_callback(handler_id, payload = {})
        case handler_id
        when "ping"
          @update_queue.enqueue([:pong, payload[:timestamp]])
          return
        when "navigate"
          navigate(payload[:path])
          return
        end

        @handlers
          .fetch(handler_id) do
            raise KeyError, "Handler not found: #{handler_id}"
          end
          .call(payload)
      rescue => e
        puts e.message
        puts e.backtrace
        error = {
          type: e.class.name,
          message: e.message,
          backtrace: e.backtrace
        }
        @update_queue.enqueue([:exception, error])
      end

      sig { returns(String) }
      def to_html
        @root&.to_html.to_s
      end

      sig { returns(T.untyped) }
      def id_tree
        @root&.id_tree
      end

      sig { params(vnode: VNode).void }
      def enqueue_update!(vnode)
        component = vnode.component
        return unless component
        return if component.dirty?

        component.dirty!
        @update_queue.enqueue(vnode)
      end

      sig { override.returns(IdGenerator::Type) }
      def next_id! = @id_generator.next!

      sig { override.params(path: String).void }
      def navigate(path)
        @update_queue.enqueue([:navigate, path])
      end

      sig { override.params(type: Symbol, payload: T.untyped).void }
      def action(type, payload)
        @update_queue.enqueue([:action, { type:, payload: }])
      end

      sig do
        params(
          ctx: UpdateContext,
          vnode: T.nilable(VNode),
          descriptor: T.nilable(Interfaces::Descriptor),
          lifecycles: T::Boolean
        ).returns(T.nilable(VNode))
      end
      def patch(ctx, vnode, descriptor, lifecycles:)
        unless vnode
          return nil unless descriptor

          vnode = init_vnode(ctx, descriptor, lifecycles:)
          ctx.insert(vnode)
          return vnode
        end

        return remove_vnode(ctx, vnode, lifecycles:) unless descriptor

        if vnode.descriptor.same?(descriptor)
          patch_vnode(ctx, vnode, descriptor, lifecycles:)
        else
          remove_vnode(ctx, vnode, lifecycles:)
          vnode = init_vnode(ctx, descriptor, lifecycles:)
          ctx.insert(vnode)
          return vnode
        end
      end

      sig { void }
      def cleanup_unused_handlers!
        @handlers.delete_if do |id, handler|
          if @handler_counts.count(id).zero?
            Console.logger.warn(self, "Removing handler #{id}")
            true
          end
        end
      end

      private

      sig do
        params(
          ctx: UpdateContext,
          vnode: VNode,
          descriptor: Interfaces::Descriptor,
          lifecycles: T::Boolean
        ).returns(VNode)
      end
      def patch_vnode(ctx, vnode, descriptor, lifecycles:)
        unless vnode.descriptor.same?(descriptor)
          raise "Can not patch different types!"
        end

        if component = vnode.component
          if component.should_update?(descriptor.props, component.next_state)
            vnode.descriptor = descriptor
            prev_props, prev_state = component.props, component.state
            component.props = descriptor.props
            component.state = component.next_state.clone

            descriptors = clean_children(component.render, parent: descriptor)

            ctx.enter(vnode) do
              vnode.children =
                update_children(
                  ctx,
                  vnode.children.compact,
                  descriptors,
                  lifecycles:
                )
            end

            update_stylesheet(ctx, component)

            component.did_update(prev_props, prev_state) if lifecycles
          end

          return vnode
        end

        type = descriptor.type

        if type.is_a?(Proc)
          vnode.descriptor = descriptor
          descriptors = Array(type.call(**descriptor.props)).compact

          ctx.enter(vnode) do
            vnode.children =
              update_children(
                ctx,
                vnode.children.compact,
                descriptors,
                lifecycles:
              )
          end

          return vnode
        end

        return vnode if vnode.descriptor == descriptor

        if descriptor.text?
          unless vnode.descriptor.text == descriptor.text
            if append = append_part(vnode.descriptor.text, descriptor.text)
              ctx.text(vnode, append, append: true)
            else
              ctx.text(vnode, descriptor.text)
            end
            vnode.descriptor = descriptor
            return vnode
          end
        else
          if vnode.descriptor.has_children? && descriptor.has_children?
            if vnode.descriptor.children != descriptor.children
              ctx.enter(vnode) do
                vnode.children =
                  update_children(
                    ctx,
                    vnode.children,
                    descriptor.children.to_a,
                    lifecycles:
                  )
              end
            end
          elsif descriptor.has_children?
            ctx.enter(vnode) do
              vnode.children =
                clean_children(
                  descriptor.children.to_a,
                  parent: descriptor
                ).map do
                  init_vnode(ctx, _1, lifecycles:).tap do |child|
                    ctx.insert(child)
                  end
                end
            end
          elsif vnode.children.length > 0
            ctx.enter(vnode) do
              vnode.children.each { remove_vnode(ctx, _1, lifecycles:) }
            end
            vnode.children = []
          elsif vnode.descriptor.text?
            ctx.text(vnode, "")
          else
            # Everything seems to be exactly the same
          end
        end

        update_handlers(vnode.props, descriptor.props)

        update_attributes(
          ctx,
          vnode,
          Utils.flatten_props(vnode.props),
          Utils.flatten_props(descriptor.props)
        )

        vnode.descriptor = descriptor

        vnode
      end

      sig do
        params(
          ctx: UpdateContext,
          vnodes: T::Array[VNode],
          lifecycles: T::Boolean
        ).returns(NilClass)
      end
      def remove_vnodes(ctx, vnodes, lifecycles:)
        vnodes.each { |vnode| remove_vnode(ctx, vnode, lifecycles:) }
        nil
      end

      sig { params(ctx: UpdateContext, component: Component::Wrapper).void }
      def update_stylesheet(ctx, component)
        # TODO: Make this more generic..
        # This only works with CSS right now.
        # Images could also be preloaded.
        # https://web.dev/preload-responsive-images/
        component.assets.each { |asset| @assets.add(asset) }
      end

      sig do
        params(
          ctx: UpdateContext,
          descriptor: Interfaces::Descriptor,
          lifecycles: T::Boolean,
          nested: T::Boolean
        ).returns(VNode)
      end
      def init_vnode(ctx, descriptor, lifecycles:, nested: false)
        vnode = VNode.build(self, ctx.dom_parent_id, descriptor)

        component = vnode.init_component

        children =
          if component
            Array(component.render).compact
          else
            descriptor.props[:children].to_a
          end

        update_stylesheet(ctx, component) if component
        # puts "\e[32mInitializing vnode #{vnode.id} #{vnode.descriptor.type} with #{children.length} children\e[0m"

        unless children.empty?
          ctx.enter(vnode) do
            vnode.children =
              clean_children(children, parent: descriptor).map do
                init_vnode(ctx, _1, lifecycles:, nested: true)
              end
          end
        end

        vnode.component&.mount if lifecycles

        update_handlers({}, vnode.props)

        vnode
      end

      sig do
        params(
          ctx: UpdateContext,
          vnode: VNode,
          lifecycles: T::Boolean,
          patch: T::Boolean
        ).returns(NilClass)
      end
      def remove_vnode(ctx, vnode, lifecycles:, patch: true)
        # puts "\e[31mRemoving vnode #{vnode.id} #{vnode.descriptor.type}\e[0m"

        vnode.component&.unmount if lifecycles
        vnode.remove!
        ctx.remove(vnode) if patch
        vnode.children.map { remove_vnode(ctx, _1, lifecycles:, patch: false) }
        update_handlers(vnode.props, {})
        nil
      end

      sig do
        params(vnode: VNode, descriptor: Interfaces::Descriptor).returns(
          T::Boolean
        )
      end
      def same?(vnode, descriptor)
        vnode.descriptor.same?(descriptor)
      end

      sig do
        params(
          ctx: UpdateContext,
          vnodes: T::Array[VNode],
          descriptors: T::Array[Interfaces::Descriptor],
          lifecycles: T::Boolean
        ).returns(T::Array[VNode])
      end
      def update_children(ctx, vnodes, descriptors, lifecycles:)
        Reconciliation.reconcile(vnodes, descriptors) do |event|
          old_ids = vnodes.map(&:id).sort

          case event
          in Reconciliation::Patches::Init => init
            init_vnode(ctx, init.descriptor, lifecycles:)
          in Reconciliation::Patches::Patch => patch
            patch_vnode(ctx, patch.vnode, patch.descriptor, lifecycles:)
          in Reconciliation::Patches::InsertBefore => insert
            if old_ids.include?(insert.vnode.id)
              ctx.move(insert.vnode, before: insert.ref)
            else
              ctx.insert(insert.vnode, before: insert.ref)
            end
            nil
          in Reconciliation::Patches::InsertAfter => insert
            if old_ids.include?(insert.vnode.id)
              ctx.move(insert.vnode, after: insert.ref)
            else
              ctx.insert(insert.vnode, after: insert.ref)
            end
            nil
          in Reconciliation::Patches::Remove => remove
            remove_vnode(ctx, remove.vnode, lifecycles:)
            nil
          end
        end
      end

      sig do
        params(old_props: Component::Props, new_props: Component::Props).void
      end
      def update_handlers(old_props, new_props)
        old_handlers = old_props.keys.select { _1.start_with?("on") }
        new_handlers = new_props.keys.select { _1.start_with?("on") }

        # FIXME: If the same handler id is used somewhere else,
        # it will be cleared too. Use RefCounter
        removed_handlers = old_handlers - new_handlers

        old_props
          .values_at(*T.unsafe(removed_handlers))
          .select { _1.is_a?(Component::HandlerRef) }
          .each { |handler| @handler_counts.release(handler.id) }

        new_props
          .values_at(*T.unsafe(new_handlers))
          .select { _1.is_a?(Component::HandlerRef) }
          .each do |handler|
            @handlers[handler.id] = handler
            @handler_counts.acquire!(handler.id)
          end
      end

      sig do
        params(
          ctx: UpdateContext,
          vnode: VNode,
          old_props: Component::Props,
          new_props: Component::Props
        ).void
      end
      def update_attributes(ctx, vnode, old_props, new_props)
        removed = old_props.keys - new_props.keys - [:children]

        new_props.each do |attr, value|
          next if attr == :children
          next if attr == :slot

          old_value = old_props[attr]

          next if value == old_props[attr]

          removed.push(attr) and next unless value
          removed.push(attr) and next if value == ""

          if attr == :style && old_value.is_a?(Hash) && value.is_a?(Hash)
            CSSAttributes.new(**old_value).patch(
              ctx,
              vnode,
              CSSAttributes.new(**value)
            )
            next
          end

          if value == true
            ctx.set_attribute(vnode, attr.to_s, attr.to_s)
          else
            ctx.set_attribute(vnode, attr.to_s, value.to_s)
          end
        end

        removed.uniq.each { |attr| ctx.remove_attribute(vnode, attr.to_s) }
      end

      sig { params(str1: String, str2: String).returns(T.nilable(String)) }
      def append_part(str1, str2)
        return nil if str1.strip.empty? || str1.length >= str2.length
        return nil unless str2.slice(0...str1.length) == str1
        str2.slice(str1.length..-1)
      end

      sig do
        params(
          children: Component::Children,
          parent: Interfaces::Descriptor
        ).returns(T::Array[Interfaces::Descriptor])
      end
      def clean_children(children, parent:)
        children
          .then { Descriptor::Factory.clean(_1, parent_type: parent) }
          .then { Descriptor::Factory.add_comments_between_texts(_1) }
      end
    end
  end
end
