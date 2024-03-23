# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "securerandom"

require "async"
require "async/barrier"
require "async/queue"

require_relative "dom"
require_relative "h"
require_relative "descriptors"
require_relative "inline_style"

module Mayu
  module Runtime
    module VNodes
      Updater =
        Data.define(:task, :queue, :vnode) do
          def self.for_vnode(vnode, parent_task: Async::Task.current)
            queue = Async::Queue.new

            task =
              parent_task.async do
                vnode.start_children

                while descriptor = queue.dequeue
                  vnode.update_sync(descriptor)
                end
              end

            Updater.new(task, queue, vnode)
          end

          def async(&)
            task.async { |subtask| yield subtask }
          end

          def enqueue(descriptor)
            queue.dequeue until queue.empty?
            queue.enqueue(descriptor)
          end

          def stop = task.stop

          def _dump = nil
          def _load = nil
        end

      class Base
        State = Data.define(:state) {}

        attr_reader :id
        attr_reader :descriptor
        attr_reader :parent

        def initialize(descriptor, parent:)
          @descriptor = descriptor
          @parent = parent
          @id = SecureRandom.alphanumeric
          @id_counter = 0
          @state = State[:initialized]
        end

        def marshal_dump
          [@id, @id_counter, @descriptor, @parent, @state]
        end

        def marshal_load(a)
          @id, @id_counter, @descriptor, @parent, @state = a
        end

        def running?
          !!@updater
        end

        def patch(patches)
          @parent.patch(patches)
        end

        def start_children
        end

        def update(descriptor)
          @updater ? @updater.enqueue(descriptor) : update_sync(descriptor)
        end

        def closest(type)
          if type === self
            self
          else
            @parent&.closest(type)
          end
        end

        def closest!(type)
          closest or raise "Could not find node type #{type}"
        end

        def start
          @updater = Updater.for_vnode(self)
        end

        def start_children
        end

        def stop
          updater, @updater = @updater, nil
          updater&.stop
        end

        def update_child_ids
          @parent.update_child_ids
        end

        def traverse(&)
          yield self
        end
      end

      class VAttributes < Base
        Listener =
          Data.define(:id, :callback) do
            def self.[](callback) = new(SecureRandom.alphanumeric(32), callback)

            def to_js = "Mayu.callback(event,'#{id}')"

            def call(payload)
              method = callback.component.method(callback.method_name)

              case method.parameters
              in []
                method.call
              in [[:req, Symbol]]
                method.call(payload)
              in [[:keyrest, Symbol]]
                method.call(**payload)
              end
            end
          end

        def initialize(...)
          super
          @attributes = {}
          @attributes = update_attributes(@descriptor.props)
        ensure
          @initialized = true
        end

        def marshal_dump
          [super, @attributes, @initialized]
        end

        def marshal_load(a)
          a => [a, attributes, initialized]
          super(a)
          @attributes = attributes
          @initialized = initialized
        end

        def update(descriptor)
          @descriptor = descriptor
          @attributes = update_attributes(@descriptor.props)
        end

        def render
          @attributes
        end

        private

        def patch(...)
          super if @initialized
        end

        def update_attributes(props)
          @attributes
            .keys
            .union(props.keys)
            .map do |prop|
              old = @attributes[prop]
              new = props[prop] || nil

              if prop == :style
                update_style(prop, old, new)
              elsif prop.start_with?("on")
                update_callback(prop, old, new)
              else
                update_attribute(prop, old, new)
              end
            end
            .compact
            .to_h
        end

        def update_style(prop, old, new)
          unless new
            patch(Patches::RemoveAttribute[@parent.id, :style])
            return
          end

          InlineStyle.diff(@parent.id, old || {}, new) { patch(_1) }

          [prop, new]
        end

        def update_callback(prop, old, new)
          if old
            return prop, old if old.callback.same?(new)

            @root.remove_listener(old)

            unless new
              patch(Patches::RemoveAttribute[@parent.id, prop])
              return
            end
          end

          return unless new

          listener = closest(VDocument).add_listener(Listener[new])
          patch(Patches::SetAttribute[@parent.id, prop, listener.to_js])

          [prop, listener]
        end

        def update_attribute(prop, old, new)
          unless new
            patch(Patches::RemoveAttribute[@parent.id, new.to_s])
            return
          end

          return prop, new.to_s if old.to_s == new.to_s

          if prop == :class
            patch(Patches::SetClassName[@parent.id, new.to_s])
          else
            patch(Patches::SetAttribute[@parent.id, prop, new.to_s])
          end

          [prop, new.to_s]
        end
      end

      class VElement < Base
        def initialize(...)
          super
          @children = VChildren.new(@descriptor.children, parent: self)
          @child_ids = @children.child_ids
          @attributes = VAttributes.new(@descriptor, parent: self)
        end

        def marshal_dump
          [super, @children, @child_ids, @attributes]
        end

        def marshal_load(a)
          a => [a, children, child_ids, attributes]
          super(a)
          @children = children
          @child_ids = child_ids
          @attributes = attributes
        end

        def traverse(&)
          yield self
          @children.traverse(&)
        end

        def child_ids = [id]

        def start_children
          @children.start
        end

        def insert
          patch(render.patch_insert)
        end

        def remove
          patch(render.patch_remove)
        end

        def render
          tag_name = self.tag_name

          DOM::Element[@id, tag_name, *@children.render, **@attributes.render]
        end

        def update_sync(descriptor)
          @descriptor = descriptor
          @attributes.update(descriptor)
          @children.update(descriptor.children)
        end

        def tag_name =
          @descriptor.type.to_s.downcase.delete_prefix("__").tr("_", "-")

        def update_child_ids
          @updater&.async do
            new_child_ids = @children.child_ids.flatten

            unless new_child_ids == @child_ids
              @child_ids = new_child_ids
              patch(Patches::ReplaceChildren[id, @child_ids])
            end
          end
        end
      end

      class VText < Base
        def update_sync(descriptor)
          return if @descriptor.to_s === descriptor.to_s
          @descriptor = descriptor
          patch(Patches::SetTextContent[id, @descriptor.to_s])
        end

        def child_ids = [@id]

        def insert
          patch(render.patch_insert)
        end

        def remove
          patch(render.patch_remove)
        end

        def render
          DOM::Text[@id, @descriptor.to_s]
        end
      end

      class VComment < Base
        def update_sync(descriptor)
          @descriptor = descriptor
        end

        def child_ids = [@id]

        def insert
          patch(render.patch_insert)
        end

        def render
          DOM::Comment[@id, @descriptor.to_s]
        end
      end

      class VChildren < Base
        STRING_SEPARATOR = Descriptors::Comment[""]

        Updated = Data.define(:node, :descriptor)
        Created = Data.define(:node)
        UpdateResult = Data.define(:children, :removed)

        attr_reader :children

        def initialize(...)
          super
          update_children([], @descriptor)
        end

        def marshal_dump
          [super, @children]
        end

        def marshal_load(a)
          a => [a, children]
          super(a)
          @children = children
        end

        def traverse(&block)
          yield self
          @children.each { |child| child.traverse(&block) }
        end

        def child_ids
          @children.map(&:child_ids).flatten
        end

        def start_children
          @children.each { |child| Async { child.start } }
        end

        def update_sync(descriptor)
          @descriptor = descriptor
          update_children(@children, @descriptor)
        end

        def insert = @children.map { _1.insert }
        def remove = @children.map { _1.remove }
        def render = @children.map { _1.render }

        private

        def update_children(old_children, descriptors)
          diff = diff_children(old_children, normalize_descriptors(descriptors))

          created = []

          @children =
            diff.children.map do |update|
              case update
              in Updated[node:, descriptor:]
                node.update(descriptor)
                node
              in Created[node:]
                created << node
                node
              end
            end

          if running?
            created.each do |node|
              node.insert
              node.start
            end
          end

          diff.removed.each do |removed|
            removed.remove
            removed.stop
          end

          update_child_ids

          # puts "\e[31m#{diff.removed.map(&:child_ids).join(", ")}\e[0m"
          # puts "\e[33m#{diff.children.select { Updated === _1 }.map(&:node).map(&:child_ids).join(", ")}\e[0m"
          # puts "\e[32m#{diff.children.select { Created === _1 }.map(&:node).map(&:child_ids).join(", ")}\e[0m"
          #

          @children
        end

        def diff_children(old_children, descriptors)
          source = old_children.dup

          new_children =
            descriptors.map do |descriptor|
              if index =
                   source.index { Descriptors.same?(descriptor, _1.descriptor) }
                found = source.delete_at(index)
                Updated[found, descriptor]
              else
                Created[VAny.new(descriptor, parent: self)]
              end
            end

          UpdateResult[new_children, source]
        end

        private

        def normalize_descriptors(descriptors)
          Array(descriptors)
            .flatten
            .map { Descriptors.descriptor_or_string(_1) }
            .compact
            .then { insert_comments_between_strings(_1) }
        end

        def insert_comments_between_strings(descriptors)
          [nil, *descriptors].each_cons(2)
            .map do |prev, descriptor|
              case [prev, descriptor]
              in [String, String]
                [STRING_SEPARATOR, descriptor]
              else
                descriptor
              end
            end
            .flatten
        end
      end

      class VSlot < Base
        def initialize(...)
          super
          @children = VChildren.new(get_children, parent: self)
        end

        def marshal_dump
          [super, @children]
        end

        def marshal_load(a)
          a => [a, children]
          super(a)
          @children = children
        end

        def traverse(&)
          yield self
          @children.traverse(&)
        end

        def child_ids = @children.child_ids

        def start_children = @children.start
        def insert = @children.insert
        def remove = @children.remove
        def render = @children.render

        def update_sync(descriptor)
          @descriptor = descriptor
          @children.update(get_children)
        end

        private

        def get_children
          component = closest(VComponent)
          name = @descriptor.props[:name]
          component.descriptor.children.slots[name]
        end
      end

      class VAny < Base
        def initialize(...)
          super
          @type = node_type_from_descriptor(@descriptor)
          @child = @type.new(@descriptor, parent: self)
          # puts "Creating #{@type} for #{@descriptor}"
        end

        def marshal_dump
          [super, @type, @child]
        end

        def marshal_load(a)
          a => [a, type, child]
          super(a)
          @type = type
          @child = child
        end

        def traverse(&)
          yield self
          @child.traverse(&)
        end

        def child_ids = @child.child_ids

        def insert = @child.insert
        def remove = @child.remove
        def render = @child.render

        def start_children = @child.start
        def update_sync(descriptor) = @child.update(descriptor)

        private

        def node_type_from_descriptor(descriptor)
          case descriptor
          in Descriptors::Element[type: :slot]
            VSlot
          in Descriptors::Element[type: :head]
            VHead
          in Descriptors::Element[type: :body]
            VBody
          in Descriptors::Element[type: Proc]
            VStateless
          in Descriptors::Element[type: Class]
            VComponent
          in Descriptors::Element
            VElement
          in Descriptors::Comment
            VComment
          else
            VText
          end
        end
      end

      class VHead < Base
        def initialize(...)
          super
          add_to_document
        end

        def traverse
          yield self
        end

        def insert = add_to_document
        def remove = remove_from_document
        def render = nil
        def start_children = nil
        def child_ids = []

        def children = @descriptor.children

        def update_sync(descriptor)
          unless @descriptor.children == descriptor.children
            @descriptor = descriptor
            add_to_document
          end
        end

        private

        def add_to_document
          closest(VDocument).add_head(self)
        end

        def remove_from_document
          closest(VDocument).remove_head(self)
        end
      end

      class VBody < VElement
        def initialize(descriptor, parent:)
          super(inject_mayu_ping(descriptor), parent:)
        end

        def update_sync(descriptor)
          super(inject_mayu_ping(descriptor))
        end

        private

        def inject_mayu_ping(descriptor)
          descriptor.with(
            children: [*descriptor.children, H[:mayu_ping, ping: "N/A"]]
          )
        end
      end

      class VStateless < Base
        def initialize(...)
          super
          @children = VChildren.new(rerender, parent: self)
        end

        def marshal_dump
          [*super, @children]
        end

        def marshal_load(a)
          a => [*a, children]
          super(a)
          @children = children
        end

        def insert = @children.insert
        def render = @children.render
        def remove = @children.remove
        def child_ids = @children.child_ids
        def start_children = @children.start_children

        def update_sync(descriptor)
          @descriptor = descriptor
          @children.update(rerender)
        end

        private

        def rerender
          @descriptor.type.call(**@descriptor.props)
        end
      end

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
            mod.assets.each do |asset|
              if asset.content_type == "text/css"
                closest(VDocument).add_stylesheet(asset.filename)
              end
            end
          end

          @context = Context.new(parent: @parent.closest(self.class)&.context)

          @instance = klass.allocate

          @instance.instance_variable_set(:@__props, @descriptor.props.freeze)
          @instance.instance_variable_set(:@__context, @context)
          @instance.instance_variable_set(:@__children, @descriptor.children.freeze)

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

          @instance.instance_variable_set(:@__children, @descriptor.children.freeze)
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
              puts "\e[1mMounting #{component_type_name}\e[0m"

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

      class VDocument < Base
        class Html < Mayu::Component::Base
          def render
            H[:html, H[:slot]]
          end
        end

        class Head < Mayu::Component::Base
          def render
            grouped =
              @__props[:descriptors]
                .group_by do |descriptor|
                  case descriptor
                  in Descriptors::Element[type: :meta, props: { charset: }]
                    puts "\e[31m%meta(charset=#{charset.inspect}) ignored\e[0m"
                    nil
                  in Descriptors::Element[type: :meta, props: { name: }]
                    "meta-name-#{name}"
                  in Descriptors::Element[type: :meta, props: { property: }]
                    "meta-property-#{name}"
                  in Descriptors::Element[type: :title]
                    "title"
                  else
                    puts "\e[31mUnsupported %head node: #{descriptor.inspect}\e[0m"
                    nil
                  end
                end
                .except(nil)
                .transform_values(&:last)

            title = grouped.delete("title")
            tags = grouped.map { |key, element| element.with(key:) }

            styles =
              @__props[:styles].map do |filename|
                H[
                  :link,
                  key: filename,
                  rel: "stylesheet",
                  href: "/.mayu/assets/#{filename}"
                ]
              end

            H[
              :__head,
              H[:meta, charset: "utf-8"],
              H[
                :script,
                type: "module",
                src: @__props[:runtime_js],
                async: true,
                key: "main_js"
              ],
              title,
              *styles,
              *tags
            ]
          end
        end

        H = Mayu::Runtime::H

        def initialize(...)
          super(...)

          @listeners = {}
          @styles = Set.new
          @head = Set.new
          @html = VComponent.new(H[Html, @descriptor], parent: self)
        end

        def add_head(vnode)
          @head.add(vnode)
          update_head
        end

        def remove_head(vnode)
          @head.delete(vnode)
          update_head
        end

        def add_stylesheet(filename)
          if @styles.add?(filename)
            puts "\e[3;36mAdding stylesheet: #{filename}\e[0m"
            update_head
          end
        end

        def add_listener(listener)
          @listeners.store(listener.id, listener)
        end

        def remove_listener(listener)
          @listeners.delete(listener.id)
        end

        def call_listener(id, payload)
          case @listeners.fetch(id).call(payload)
          in Patches::RenderError => e
            patch(e)
          else
            nil
          end
        end

        def marshal_dump
          [super, @html, @listeners, @styles, @head]
        end

        def marshal_load(a)
          a => [a, html, listeners, styles, head]
          super(a)
          @html = html
          @listeners = listeners
          @styles = styles
          @head = head
        end

        def update_child_ids
        end

        def start_children
          @html.start
        end

        def update_sync(descriptor)
          @descriptor = descriptor
          @html.update(init_html)
        end

        def closest(type)
          if type === self
            self
          else
            nil
          end
        end

        def render
          @html.update(init_html)
          DOM::Document[*@html.render, id: @id]
        end

        private

        def init_html
          H[Html, init_head, @descriptor]
        end

        def init_head
          H[
            Head,
            runtime_js: @parent.runtime_js,
            styles: @styles,
            descriptors: @head.map(&:children).flatten.compact
          ]
        end

        def update_head
          @html&.traverse do |v|
            if v.descriptor in Descriptors::Element
              if v.descriptor.type == Head
                v.update(init_head)
                break
              end
            end
          end
        end
      end
    end
  end
end
