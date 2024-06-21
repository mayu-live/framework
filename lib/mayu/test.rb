#!/usr/bin/env ruby -rbundler/setup
# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "async"
require "async/notification"
require "nokogiri"
require "syntax_tree/xml"
require "pry"

require "rouge"

require_relative "runtime"
require_relative "runtime/h"
require_relative "runtime/dom"
require_relative "component"

module Mayu
  module Test
    module Helpers
      def render(descriptor)
        Sync do
          page =
            Mayu::Test::Page.new(
              Mayu::Runtime.init(descriptor, runtime_js: "test.js")
            )

          Fiber[:current_test_page] = page

          page.start

          sleep 0.01

          yield page
        rescue => e
          puts e.message
          puts e.backtrace
          raise
        ensure
          page.stop
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

      def current_page
        Fiber[:current_test_page] or raise "There is no current page"
      end

      def enable_step!
        Fiber[:test_enable_step] = true
      end

      def capture_patches(&block)
        patches = []

        task = Async do
          current_page.on_patch do
            patches.push(patch)
          end
        end

        begin
          yield
        ensure
          task.stop
        end

        patches
      end
    end

    module Filters
      Tag = Data.define(:name, :text, :attributes) do
        def self.[](tag, text: nil, **attributes)
          tag = tag.to_s if tag in Symbol
          new(tag.to_s, text, attributes)
        end

        def match?(node)
          case name
          in "#text"
            if node in Nokogiri::XML::Text
              return true unless text
              text === node.content
            end
          in "#comment"
            if node in Nokogiri::XML::Comment
              return true unless text
              text === node.content
            end
          in String => tag_name
            return false unless node in Nokogiri::XML::Element
            return false unless tag_name === node.name

            attributes.each do |attr, value|
              unless value === node.attributes["name"]&.value
                return false
              end
            end

            return true unless text
            text === node.content
          end
        end

        def to_proc
          ->(node) { match?(node) }
        end
      end
    end

    class Page
      class NodeNotFoundError < StandardError
      end
      class NoListenerError < StandardError
      end

      Node = Data.define(:page, :node) do
        def name
          node.name
        end

        def [](attr)
          node.attributes.fetch(attr.to_s) do
            raise "Could not find attribute #{attr.to_s} in #{node.to_html}"
          end.value
        end

        def attributes
          node.attributes.transform_values(&:value)
        end

        def content
          node.content
        end

        def traverse(&)
          node.traverse(&)
        end

        def find(&)
          traverse do |node|
            return self.class.new(page, node) if yield node
          end

          nil
        end

        def find!(&)
          find(&) or raise NodeNotFoundError
        end

        def click
          attrs = attributes

          target = {
            name: attrs["name"],
            value: attrs["value"],
          }

          page.callback(callback_id(:onclick), {
            target:,
            currentTarget: target,
          })
        end

        def input(value)
          page.callback(callback_id(:oninput), { currentTarget: { value: } })
        end

        def type_input(value)
          page.callback(callback_id(:oninput), { currentTarget: { value: } })

          value.each_char.reduce("") do |str, char|
            (str + char).tap do
              yield if block_given?
              self.input(_1)
              sleep 0.05
            end
          end
        end

        private

        def callback_id(attribute)
          if value = node.attributes[attribute.to_s]&.value
            value[/\AMayu\.callback\(event,'(?<id>[^\)]+)'\)\z/, :id]
          end
        end
      end

      attr_reader :on_patch

      def initialize(engine)
        @engine = engine
        rendered = @engine.render
        @nodes = {}
        @doc = Nokogiri::HTML5(rendered.to_html)
        @patches = []
        @on_patch = Async::Notification.new
        setup_tree(@doc, rendered.id_node)
      end

      def start
        @task ||= Async do
          @engine.run do |patch|
            puts format(
              "\e[33m%s\e[0m %s",
              patch.class.name.split("::").last,
              patch.to_h.map { |k, v|
                format(
                  "\e[34m%s\e[0m: \e[94m%s\e[0m",
                  k,
                  v.inspect
                )
              }.join(", ")
            )

            @patches.push(patch)

            case patch
            in Mayu::Runtime::Patches::SetTextContent[id:, content:]
              @nodes.fetch(id).content = content
            in Mayu::Runtime::Patches::CreateTree[html:, tree:]
              Nokogiri::HTML5.fragment(html).children => [node]
              setup_tree(node, tree)
            in Mayu::Runtime::Patches::SetAttribute[id:, name:, value:]
              node = @nodes.fetch(id)
              node[name.to_s] = value
            in Mayu::Runtime::Patches::ReplaceChildren[id:, child_ids:]
              node = @nodes.fetch(id)
              children = child_ids.map { @nodes.fetch(_1) }
              node_set = Nokogiri::XML::NodeSet.new(@doc, children)
              node.children = node_set
            in Mayu::Runtime::Patches::RemoveNode[id:]
              @nodes.delete(id)
            else
              puts "\e[33mUnhandled #{patch.inspect}\e[0m"
            end
          end
        ensure
          @task = nil
        end
      end

      def stop
        @task.stop
      end

      def step
        interactive = Fiber[:test_enable_step] && $stdout.tty?
        clear = interactive ? "\e[H\e[2J" : "#".*(40).+("\n")

        puts format(
          "%s%s\n\e[3m %s \e[0m\n",
          clear,
          self.class.format_xhtml(to_xhtml).strip,
          "Press return to step"
        )

        if interactive
          gets
        else
          sleep 0.05
        end
      end

      def to_xhtml
        SyntaxTree::XML.format(@doc.to_xhtml)
      end

      def traverse(&) = @doc.traverse(&)

      def find(...)
        Node.new(self, @doc).find(...)
      end

      def find!(...)
        Node.new(self, @doc).find!(...)
      end

      def callback(id, payload = {})
        puts "Callback #{id} #{payload.inspect}"
        @engine.callback(id, payload)
      end

      def emit(event)
        event.call(@engine)
      end

      private

      def setup_tree(dom_node, id_node)
        return unless dom_node
        return unless id_node

        unless dom_node.name == id_node.name.delete_prefix("#").downcase
          raise "\e[31m#{id_node.id} should be #{id_node.name.inspect}, but found #{dom_node.name.inspect}\e[0m"
        end

        @nodes.store(id_node.id, dom_node)

        dom_node
          .children.to_a
          .reject do
            _1.node_type == 14
          end
          .zip(id_node.children)
          .each do |dom_child, id_child|
            setup_tree(dom_child, id_child)
          end
      end

      def self.format_xhtml(source)
        theme = Rouge::Themes::Gruvbox.dark!
        formatter = Rouge::Formatters::Terminal256.new(theme)
        lexer = Rouge::Lexers::XML.new
        source
          .then { lexer.lex(_1) }
          .then { formatter.format(_1) }
      end
    end
  end
end
