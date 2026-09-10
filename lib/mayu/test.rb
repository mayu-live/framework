#!/usr/bin/env ruby -rbundler/setup
# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "async"
require "oga"
require "rouge"

require_relative "runtime"
require_relative "runtime/h"
require_relative "runtime/dom"
require_relative "component"
require_relative "test/query"

module Mayu
  module Test
    class FakeMetrics
      NullCounter = Data.define { def increment(**) = nil }
      NullSummary = Data.define { def observe(_value = nil, **) = nil }

      def component_mount_count = NullCounter.new
      def component_children_update_times = NullSummary.new
      def component_patch_times = NullSummary.new
      def update_child_id_count = NullCounter.new
      def update_chunk_count = NullCounter.new
      def session_callback_count = NullCounter.new
      def session_ping_count = NullCounter.new

      def update_summary(_summary, labels: {})
        yield
      end
    end

    module Helpers
      def render(renderable, *children, **props, &block)
        descriptor = descriptor_for(renderable, children, props)

        if Async::Task.current?
          render_in_current_task(descriptor, &block)
        elsif block
          Sync { render_in_current_task(descriptor, &block) }
        else
          raise "render without a block requires Mayu::Test::Case"
        end
      end

      def find(*, **)
        find!(*, **)
      rescue Page::NodeNotFoundError
        nil
      end

      def find!(*, **)
        filter = Mayu::Test::Filters::Tag[*, **]
        current_page.find!(&filter)
      end

      def at_xpath(query)
        current_page.at_xpath(query)
      end

      def current_page
        Fiber[:current_test_page] or raise "There is no current page"
      end

      alias_method :screen, :current_page

      def enable_step!
        Fiber[:test_enable_step] = true
      end

      def capture_patches
        offset = current_page.patches.length
        yield
        current_page.patches.drop(offset)
      end

      private

      def descriptor_for(renderable, children, props)
        case renderable
        when Mayu::Runtime::Descriptors::Element,
             Mayu::Runtime::Descriptors::Context,
             Mayu::Runtime::Descriptors::Comment,
             Mayu::Runtime::Descriptors::RawText
          raise ArgumentError, "a descriptor cannot receive children or props" if
            children.any? || props.any?

          renderable
        else
          Mayu::Runtime::H[renderable, *children, **props]
        end
      end

      def render_in_current_task(descriptor)
        page =
          Mayu::Test::Page.new(
            Mayu::Runtime.init(
              descriptor,
              metrics: Mayu::Test::FakeMetrics.new,
              runtime_js: "test.js"
            )
          )
        previous_page = Fiber[:current_test_page]
        Fiber[:current_test_page] = page
        __register_test_page(page) if respond_to?(:__register_test_page, true)
        page.start
        page.settle

        return page unless block_given?

        begin
          yield page
        ensure
          page.stop
          __unregister_test_page(page) if
            respond_to?(:__unregister_test_page, true)
          Fiber[:current_test_page] = previous_page
        end
      end
    end

    module Filters
      Tag =
        Data.define(:name, :text, :attributes) do
          def self.[](tag, text: nil, **attributes)
            new(tag.to_s, text, attributes)
          end

          def match?(node)
            case name
            when "#text"
              return false unless node.is_a?(Oga::XML::Text)
            when "#comment"
              return false unless node.is_a?(Oga::XML::Comment)
            else
              return false unless node.is_a?(Oga::XML::Element)
              return false unless name === node.name
              return false unless attributes.all? do |attr, value|
                value === node.get(attr.to_s)
              end
            end

            !text || text === node.text
          end

          def to_proc
            ->(node) { match?(node) }
          end
        end
    end

    class Page
      include QueryMethods

      DEFAULT_SETTLE_TIMEOUT = 1.0

      class NodeNotFoundError < StandardError
      end

      class NoListenerError < StandardError
      end

      class SettleTimeoutError < StandardError
      end

      Node =
        Data.define(:page, :node) do
          include QueryMethods

          def name = node.name
          def [](attr) = node.get(attr.to_s)

          def attributes
            return {} unless node.respond_to?(:attributes)

            node.attributes.map { [it.name, it.value] }.to_h
          end

          def text = node.text
          alias_method :content, :text

          def traverse(&)
            yield self
            node.each_node do |child|
              yield self.class.new(page, child)
            end
          end

          def at_xpath(query)
            result = node.at_xpath(query)
            self.class.new(page, result) if result
          end

          def find(&)
            return self if yield node

            node.each_node do |child|
              return self.class.new(page, child) if yield child
            end
            nil
          end

          def find!(&)
            find(&) or raise NodeNotFoundError
          end

          def click
            target = {
              name: attributes["name"],
              value: attributes["value"]
            }
            page.fire_event(:click, self, target:, currentTarget: target)
            self
          end

          def input(value)
            node.set("value", value.to_s) if
              node.is_a?(Oga::XML::Element)
            page.fire_event(
              :input,
              self,
              currentTarget: {
                value: value.to_s
              }
            )
            self
          end

          def type(value)
            value.to_s.each_char.reduce(self["value"].to_s) do |current, char|
              input(current + char)
              yield self if block_given?
              current + char
            end
            self
          end

          alias_method :type_input, :type

          private

          def query_page = page
          def query_container = node
        end

      attr_reader :patches

      def initialize(engine, settle_timeout: DEFAULT_SETTLE_TIMEOUT)
        @engine = engine
        @settle_timeout = settle_timeout
        @nodes = {}
        @listener_bindings = {}
        @doc = Oga.parse_html(@engine.render)
        @patches = []
        setup_tree(@doc, @engine.dom_id_tree)
        @engine.listener_patches.each { |patch| apply_patch(patch) }
      end

      def fragment = @doc
      def html = @doc.to_xml

      def start
        @task ||=
          Async do
            @engine.start

            loop do
              patch = @engine.dequeue_patch
              if patch.is_a?(Mayu::Runtime::VNodes::Updater::Synchronization)
                patch.completion.enqueue(true)
              else
                each_patch(patch) do |item|
                  @patches << item
                  apply_patch(item)
                end
              end
            end
          ensure
            @engine.stop
            @task = nil
          end
      end

      def stop
        @task&.stop
        @task = nil
        @engine.stop
        self
      end

      def settle
        Async::Task.current.with_timeout(@settle_timeout) do
          @engine.synchronize
        end
        self
      rescue Async::TimeoutError
        raise SettleTimeoutError,
          "Mayu page did not settle within #{@settle_timeout}s\n\n#{html}"
      end

      def step
        interactive = Fiber[:test_enable_step] && $stdout.tty?
        return settle unless interactive

        puts format(
          "\e[H\e[2J%s\n\e[3m %s \e[0m\n",
          self.class.format_html(html),
          "Press return to step"
        )
        gets
        settle
      end

      def traverse(&) = Node.new(self, @doc).traverse(&)

      def find(...)
        Node.new(self, @doc).find(...)
      end

      def find!(...)
        Node.new(self, @doc).find!(...)
      end

      def at_xpath(query)
        result = @doc.at_xpath(query)
        Node.new(self, result) if result
      end

      def fire_event(event, node, payload = nil, **fields)
        unless node.is_a?(Node) && node.page.equal?(self)
          raise ArgumentError,
            "fire_event expects a node from this rendered page"
        end

        event = event.to_s.delete_prefix("on")
        dom_id = @nodes.key(node.node)
        id = @listener_bindings[[dom_id, event]]
        unless id
          raise NoListenerError,
            "#{node.name} does not have a Mayu on#{event} listener"
        end

        payload = payload ? payload.merge(fields) : fields
        callback(id, payload)
      end

      def callback(id, payload = {})
        raise NoListenerError, "Missing callback listener ID" unless id

        completion = @engine.callback(id, payload)
        Async::Task.current.with_timeout(@settle_timeout) do
          completion&.dequeue
          @engine.synchronize
        end
        self
      rescue Async::TimeoutError
        raise SettleTimeoutError,
          "Mayu callback #{id.inspect} did not settle within #{@settle_timeout}s\n\n#{html}"
      end

      def emit(event)
        event.call(@engine)
        settle
      end

      def self.format_html(source)
        theme = Rouge::Themes::Gruvbox.dark!
        formatter = Rouge::Formatters::Terminal256.new(theme)
        lexer = Rouge::Lexers::HTML.new
        formatter.format(lexer.lex(source))
      end

      private

      def query_page = self
      def query_container = @doc

      def each_patch(patch, &block)
        case patch
        when Mayu::Runtime::Patches::ViewTransition
          each_patch(patch.patches, &block)
        when Mayu::Runtime::Patches::Batch
          patch.patches.each { |item| each_patch(item, &block) }
        when Array
          patch.each { |item| each_patch(item, &block) }
        else
          yield patch
        end
      end

      def apply_patch(item)
        case item
        in Mayu::Runtime::Patches::Initialize[id_tree:]
          @nodes.clear
          @listener_bindings.clear
          setup_tree(@doc, id_tree)
        in Mayu::Runtime::Patches::CreateTree[html:, tree:]
          node = Oga.parse_html(html).children.first
          setup_tree(node, tree)
        in Mayu::Runtime::Patches::CreateElement[id:, type:]
          @nodes[id] = Oga::XML::Element.new(name: type.to_s)
        in Mayu::Runtime::Patches::CreateTextNode[id:, content:]
          @nodes[id] = Oga::XML::Text.new(text: content.to_s)
        in Mayu::Runtime::Patches::CreateComment[id:, content:]
          @nodes[id] = Oga::XML::Comment.new(text: content.to_s)
        in Mayu::Runtime::Patches::SetTextContent[id:, content:]
          fetch_node!(id).text = content.to_s
        in Mayu::Runtime::Patches::ReplaceData[id:, offset:, count:, data:]
          node = fetch_node!(id)
          node.text = node.text.dup.tap { it[offset, count] = data }
        in Mayu::Runtime::Patches::InsertData[id:, offset:, data:]
          node = fetch_node!(id)
          node.text = node.text.dup.insert(offset, data)
        in Mayu::Runtime::Patches::DeleteData[id:, offset:, count:]
          node = fetch_node!(id)
          node.text = node.text.dup.tap { it.slice!(offset, count) }
        in Mayu::Runtime::Patches::SetAttribute[id:, name:, value:]
          fetch_node!(id).set(normalize_attribute_name(name), value.to_s)
        in Mayu::Runtime::Patches::RemoveAttribute[id:, name:]
          fetch_node!(id).unset(normalize_attribute_name(name))
        in Mayu::Runtime::Patches::SetListener[id:, name:, listener_id:]
          @listener_bindings[[id, name.to_s]] = listener_id
        in Mayu::Runtime::Patches::RemoveListener[id:, name:, listener_id:]
          key = [id, name.to_s]
          @listener_bindings.delete(key) if @listener_bindings[key] == listener_id
        in Mayu::Runtime::Patches::SetClassName[id:, class_name:]
          fetch_node!(id).set("class", class_name.to_s)
        in Mayu::Runtime::Patches::AddClass[id:, classes:]
          node = fetch_node!(id)
          node.set("class", (node.get("class").to_s.split | classes).join(" "))
        in Mayu::Runtime::Patches::RemoveClass[id:, classes:]
          node = fetch_node!(id)
          node.set("class", (node.get("class").to_s.split - classes).join(" "))
        in Mayu::Runtime::Patches::SetCSSProperty[id:, name:, value:]
          set_css_property(fetch_node!(id), name, value)
        in Mayu::Runtime::Patches::RemoveCSSProperty[id:, name:]
          set_css_property(fetch_node!(id), name, nil)
        in Mayu::Runtime::Patches::ReplaceChildren[id:, child_ids:]
          node = fetch_node!(id)
          node.children = Oga::XML::NodeSet.new(child_ids.map { fetch_node!(it) })
        in Mayu::Runtime::Patches::RemoveNode[id:]
          remove_node(id)
        else
          nil
        end
      end

      def normalize_attribute_name(name)
        return "value" if name.to_s == "initial_value"

        name.to_s.delete("_")
      end

      def set_css_property(node, name, value)
        styles =
          node
            .get("style")
            .to_s
            .split(";")
            .filter_map do |declaration|
              key, current = declaration.split(":", 2).map(&:strip)
              [key, current] unless key.to_s.empty?
            end
            .to_h
        value.nil? ? styles.delete(name.to_s) : styles[name.to_s] = value.to_s
        node.set(
          "style",
          styles.map { |key, current| "#{key}:#{current}" }.join(";")
        )
      end

      def setup_tree(dom_node, id_node)
        return unless dom_node && id_node

        if dom_node.is_a?(Oga::XML::Element) &&
            dom_node.name != id_node.name.downcase
          raise "#{id_node.id} should be #{id_node.name.inspect}, but found #{dom_node.name.inspect}"
        end

        @nodes[id_node.id] = dom_node
        dom_node
          .children
          .reject { it.is_a?(Oga::XML::Document) }
          .reject { it.is_a?(Oga::XML::Text) && it.text == "\n" }
          .zip(id_node.children || [])
          .each { |dom_child, id_child| setup_tree(dom_child, id_child) }
      end

      def remove_node(id)
        node = @nodes.delete(id)
        return unless node

        removed_ids = [id]

        node.each_node do |child|
          pair = @nodes.find { |_node_id, candidate| candidate.equal?(child) }
          if pair
            removed_ids << pair.first
            @nodes.delete(pair.first)
          end
        end

        @listener_bindings.delete_if do |(node_id, _event), _listener_id|
          removed_ids.include?(node_id)
        end
      end

      def fetch_node!(id)
        @nodes.fetch(id) { raise "Could not find node with id #{id.inspect}" }
      end
    end
  end
end

require_relative "test/case"
