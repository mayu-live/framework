# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

module Mayu
  module Runtime
    module VNodes
      class VDocument < Base
        class InternalComponentBase < Mayu::Component::Base
          def self.module_path = "(internal)::#{self.name}"
        end

        class Html < InternalComponentBase
          def render
            H[:html, H[:slot]]
          end
        end

        class Head < InternalComponentBase
          def self.module_path = "(internal)::#{self.name}"

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
                  in Descriptors::Element[type: :link]
                    "link"
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
              if runtime_js = @__props[:runtime_js]
                H[
                  :script,
                  type: "module",
                  src: runtime_js,
                  async: true,
                  key: "runtime_js"
                ]
              end,
              title,
              *styles,
              *tags
            ]
          end
        end

        H = Mayu::Runtime::H

        attr_reader :styles

        def initialize(...)
          super(...)

          @listeners = {}
          @styles = Set.new
          @head = Set.new
          @html = VComponent.new(H[Html, @descriptor], parent: self)
        end

        def ancestor_info
          DOMNestingValidation::AncestorInfo::EMPTY
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
            # puts "\e[3;36mAdding stylesheet: #{filename}\e[0m"
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
          listener =
            @listeners.fetch(id) do
              Console.logger.error(self, "Listener #{id} not found")
              return
            end

          metrics.session_callback_count.increment(
            labels: listener.metric_labels
          )

          begin
            listener.call(payload)
          rescue => e
            puts Modules::System.current.format_exception(e)

            if module_path = listener.callback.component.class.module_path
              mod = Modules::System.current.get_mod(module_path)

              patch(
                Patches::RenderError[
                  module_path,
                  e.class.name,
                  e.message,
                  e.backtrace,
                  mod.source_map.input,
                  []
                ]
              )
            end
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

        def update(descriptor)
          @descriptor = descriptor
          @html.apply(init_html)
        end

        def closest(type)
          if type === self
            self
          else
            nil
          end
        end

        def render
          @html.apply(init_html)
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
                v.apply(init_head)
                break
              end
            end
          end
        end
      end
    end
  end
end
