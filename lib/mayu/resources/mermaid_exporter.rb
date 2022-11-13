# frozen_string_literal: true
# typed: strict

require "base64"
require "zlib"
require_relative "dependency_graph"

module Mayu
  module Resources
    class MermaidExporter
      extend T::Sig

      GRAPH_DIRECTION = "LR" # Left to right

      sig { params(graph: DependencyGraph).void }
      def initialize(graph)
        @graph = graph
      end

      sig { returns(String) }
      def to_url
        data = {
          code: to_source,
          mermaid: JSON.generate({ theme: "dark" }),
          updateEditor: false,
          autoSync: false,
          updateDiagram: false,
          editorMode: "code"
        }

        pako =
          data
            .then { JSON.generate(_1) }
            .then { Zlib.deflate(_1) }
            .then { Base64.urlsafe_encode64(_1) }

        "https://mermaid.live/view#pako:#{pako}"
      end

      sig { returns(String) }
      def to_source
        StringIO.new.tap { write_source(_1) }.tap(&:rewind).read.to_s
      end

      sig { params(out: StringIO).returns(StringIO) }
      def write_source(out)
        entries =
          @graph
            .overall_order(only_leaves: false)
            .filter { @graph.get_resource(_1)&.exists? }

        tree = make_tree(entries.map { _1.split("/") })
        out.puts "graph #{GRAPH_DIRECTION}"

        out.puts "  subgraph routes"
        print_routes(out, tree.dig("", "app", "pages") || {})
        out.puts "  end"

        print_route_edges(out, tree.dig("", "app", "pages") || {})

        print_subgraphs(out, tree)

        entries.each do |entry|
          @graph
            .direct_dependencies_of(entry)
            .each { |dep| out.puts "  #{encode(entry)}-->#{encode(dep)}" }
        rescue StandardError
          next
        end

        entries.each do |entry|
          unless @graph.get_resource(entry)&.exists?
            out.puts "  class #{encode(entry)} NonExistant"
          end

          filetype_class(entry)&.tap do
            out.puts "  class #{encode(entry)} #{_1}"
          end
        end

        out.puts <<~EOF.gsub(/^/, "  ")
        style routes stroke:#09c,stroke-width:5,fill:#f0f;
        classDef cluster fill:#0003;
        classDef Ruby fill:#600,stroke:#900,stroke-width:3px;
        classDef Image fill:#069,stroke:#09c,stroke-width:3px;
        classDef CSS fill:#063,stroke:#096,stroke-width:3px;
        classDef NonExistant opacity:50%,stroke-dasharray:5px;
        linkStyle default fill:transparent,opacity:50%;
      EOF

        out
      end

      private

      sig { params(path: String).returns(T.nilable(String)) }
      def filetype_class(path)
        case File.extname(path)
        when ".rb"
          "Ruby"
        when ".css"
          "CSS"
        when ".png"
          "Image"
        end
      end

      sig { params(str: String).returns(String) }
      def encode(str)
        str.gsub("/", "__").gsub("[", "__").gsub("]", "__")
      end

      sig { params(str: String).returns(String) }
      def escape(str)
        str.gsub(/\W/) { |ch| ch.codepoints.map { |cp| "##{cp};" }.join }
      end

      sig { params(str: String).returns(String) }
      def display_name(str)
        case File.extname(str)
        when ".rb"
          "fa:fa-gem #{str}&nbsp;"
        when ".css"
          "fab:fa-css3 #{str}&nbsp;"
        when ".png"
          "fa:fa-image #{str}&nbsp;"
        else
          str
        end
      end

      sig do
        params(out: StringIO, node: T.untyped, path: T::Array[String]).void
      end
      def print_routes(out, node, path = [])
        node.each do |key, value|
          path2 = path + [key]

          if value.is_a?(String)
            if key == "page.rb" || key == "page.haml"
              pathstr = path.flatten.join("/").sub(%r{\A/?}, "/")
              out.puts "    ROUTE__#{encode(value)}[#{pathstr.inspect}]"
            end
          else
            print_routes(out, value, path2)
          end
        end
      end

      sig do
        params(out: StringIO, node: T.untyped, path: T::Array[String]).void
      end
      def print_route_edges(out, node, path = [])
        node.each do |key, value|
          path2 = path + [key]

          if value.is_a?(String)
            if key == "page.rb" || key == "page.haml"
              pathstr = path.flatten.join("/").sub(%r{\A/?}, "/")
              out.puts "  ROUTE__#{encode(value)}-->#{encode(value)}"
            end
          else
            print_route_edges(out, value, path2)
          end
        end
      end

      sig do
        params(out: StringIO, node: T.untyped, path: T::Array[String]).void
      end
      def print_subgraphs(out, node, path = [])
        level = path.length
        indent = "  " * level.succ

        node.each do |key, value|
          path2 = path + [key]

          if value.is_a?(String)
            out.puts "#{indent}#{encode(value)}[#{display_name(key).inspect}]"
          else
            pathstr = path2.flatten.join("/").sub(%r{\A/?}, "/")
            out.puts "#{indent}subgraph PATH#{encode(pathstr)}[#{pathstr.inspect}]"
            print_subgraphs(out, value, path2)
            out.puts "#{indent}end"
          end
        end
      end

      sig do
        params(entries: T::Array[T::Array[String]], level: Integer).returns(
          T.untyped
        )
      end
      def make_tree(entries, level = 0)
        entries
          .group_by { _1[level] }
          .transform_values do |paths|
            paths
              .partition { _1.length.pred <= level.succ }
              .then do |leaves, branches|
                leaves.each_with_object(
                  make_tree(branches, level + 1)
                ) { |leaf, obj| obj[leaf.last] = leaf.join("/") }
              end
          end
      end
    end
  end
end
