# frozen_string_literal: true
# typed: strict

require "base64"
require "zlib"
require_relative "dependency_graph"

module Mayu
  module Resources
    class DotExporter
      extend T::Sig

      sig { params(graph: DependencyGraph).void }
      def initialize(graph)
        @graph = graph
      end

      sig { returns(String) }
      def to_source
        StringIO.new.tap { write_source(_1) }.tap(&:rewind).read.to_s
      end

      sig { params(out: StringIO).returns(StringIO) }
      def write_source(out)
        entries = @graph.overall_order(only_leaves: false)
        tree = make_tree(entries.map { _1.split("/") })

        out.puts <<~EOF
        strict digraph "dependency-cruiser output" {
            ordering="out" rankdir="LR" splines="ortho" overlap="false" nodesep="0.16" ranksep="0.5" fontname="Helvetica-bold" fontsize="9" style="rounded,bold,filled" fillcolor="#ffffff" compound="true"
            node [shape="box" style="rounded, filled" height="0.2" color="black" fillcolor="#ffffcc" fontcolor="black" fontname="Helvetica" fontsize="9"]
            edge [arrowhead="normal" arrowsize="0.6" penwidth="2.0" color="#00000033" fontname="Helvetica" fontsize="9"]

      EOF

        entries.each do |entry|
          fillcolor = "#bbfeff"
          out.puts "    #{entry.inspect} [label=<#{File.dirname(entry)}<BR/><B>#{File.basename(entry)}</B>> tooltip=#{File.basename(entry).inspect} fillcolor=#{fillcolor.inspect}]"

          @graph
            .direct_dependencies_of(entry)
            .each do |dep|
              color = "#e5009b99"
              out.puts "    #{entry.inspect} -> #{dep.inspect} [color=#{color.inspect}]"
            end
        end

        out.puts "}"
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
            if key == "page.rb"
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
            if key == "page.rb"
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
