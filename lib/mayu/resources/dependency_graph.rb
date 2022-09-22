# frozen_string_literal: true
# typed: strict

require "tsort"
require "set"
require "cgi"
require_relative "mermaid_exporter"
require_relative "dot_exporter"

module Mayu
  module Resources
    class DependencyGraph
      extend T::Sig
      # This is basically a reimplementation of this library:
      # https://github.com/jriecken/dependency-graph

      class Direction < T::Enum
        enums do
          Incoming = new(:incoming)
          Outgoing = new(:outgoing)
        end
      end

      class Node
        extend T::Sig

        sig { returns(Resource) }
        attr_reader :resource
        sig { returns(T::Set[String]) }
        attr_reader :incoming
        sig { returns(T::Set[String]) }
        attr_reader :outgoing

        sig { params(resource: Resource).void }
        def initialize(resource)
          @resource = resource
          @incoming = T.let(Set.new, T::Set[String])
          @outgoing = T.let(Set.new, T::Set[String])
        end

        sig { params(id: String).void }
        def delete(id)
          @incoming.delete(id)
          @outgoing.delete(id)
        end

        MarshalFormat =
          T.type_alias { [Resource, T::Set[String], T::Set[String]] }

        sig { returns(MarshalFormat) }
        def marshal_dump
          [@resource, @incoming, @outgoing]
        end

        sig { params(dumped: MarshalFormat).void }
        def marshal_load(dumped)
          @resource, @incoming, @outgoing = dumped
        end
      end

      sig { void }
      def initialize
        @nodes = T.let({}, T::Hash[String, Node])
      end

      sig { returns(Integer) }
      def size = @nodes.size

      sig { params(id: String).returns(T::Boolean) }
      def include?(id) = @nodes.include?(id)

      sig { params(id: String, resource: Resource).returns(Resource) }
      def add_node(id, resource)
        (@nodes[id] ||= Node.new(resource)).resource
      end

      sig { params(id: String).void }
      def delete_node(id)
        return unless @nodes.include?(id)
        @nodes.delete(id)
        delete_connections(id)
      end

      sig { params(id: String).void }
      def delete_connections(id)
        @nodes.each { |node| node.delete(id) }
      end

      sig { params(id: String).returns(T.nilable(Resource)) }
      def get_resource(id)
        @nodes[id]&.resource
      end

      sig { params(id: String).returns(T::Boolean) }
      def has_node?(id)
        @nodes.include?(id)
      end

      sig { params(source_id: String, target_id: String).void }
      def add_dependency(source_id, target_id)
        with_source_and_target(source_id, target_id) do |source, target|
          source.outgoing.add(target_id)
          target.incoming.add(source_id)
        end
      end

      sig { params(source_id: String, target_id: String).void }
      def remove_dependency(source_id, target_id)
        with_source_and_target(source_id, target_id) do |source, target|
          source.outgoing.delete(target_id)
          source.incoming.delete(source_id)
        end
      end

      sig { params(id: String).returns(T::Array[String]) }
      def direct_dependencies_of(id)
        @nodes.fetch(id).outgoing.to_a
      end

      sig { params(id: String).returns(T::Array[String]) }
      def direct_dependants_of(id)
        @nodes.fetch(id).incoming.to_a
      end

      sig do
        params(
          id: String,
          started_at: T.nilable(String),
          only_leaves: T::Boolean
        ).returns(T::Set[String])
      end
      def dependencies_of(id, started_at = nil, only_leaves: false)
        raise "Circular" if id == started_at

        @nodes
          .fetch(id)
          .outgoing
          .map do |dependency|
            dependencies = dependencies_of(dependency, started_at || id)

            if !only_leaves || dependencies.empty?
              dependencies.add(dependency)
            else
              dependencies
            end
          end
          .reduce(Set.new, &:merge)
      end

      sig do
        params(
          id: String,
          started_at: T.nilable(String),
          only_leaves: T::Boolean
        ).returns(T::Set[String])
      end
      def dependants_of(id, started_at = nil, only_leaves: false)
        raise "Circular" if id == started_at

        @nodes
          .fetch(id)
          .incoming
          .map do |dependant|
            dependants = dependants_of(dependant, started_at || id)
            if !only_leaves || dependants.empty?
              dependants.add(dependant)
            else
              dependants
            end
          end
          .reduce(Set.new, &:merge)
      end

      sig { returns(T::Array[String]) }
      def entry_nodes
        @nodes.filter { _2.incoming.empty? }.keys
      end

      sig { params(only_leaves: T::Boolean).returns(T::Array[String]) }
      def overall_order(only_leaves: true)
        TSort.tsort(
          ->(&b) { @nodes.keys.each(&b) },
          ->(key, &b) { @nodes[key]&.outgoing&.each(&b) }
        )
      end

      sig { returns(String) }
      def to_dot
        DotExporter.new(self).to_source
      end

      sig { returns(String) }
      def to_mermaid_url
        MermaidExporter.new(self).to_url
      end

      sig { returns(T::Array[String]) }
      def paths
        @nodes.keys
      end

      sig { params(block: T.proc.params(arg0: Resource).void).void }
      def each_resource(&block)
        @nodes.each_value { |node| yield node.resource }
      end

      MarshalFormat = T.type_alias { T::Hash[String, Node] }

      sig { returns(MarshalFormat) }
      def marshal_dump
        @nodes
      end

      sig { params(nodes: MarshalFormat).void }
      def marshal_load(nodes)
        @nodes = nodes
      end

      sig do
        params(
          id: String,
          direction: Direction,
          visited: T::Set[String],
          block: T.proc.params(arg0: String).void
        ).void
      end
      def dfs2(id, direction, visited: T::Set[String].new, &block)
        if visited.include?(id)
          return
        else
          visited.add(id)
        end

        @nodes
          .fetch(id)
          .send(direction.serialize)
          .each { dfs2(_1, direction, visited:, &block) }

        yield id
      end

      private

      sig do
        params(
          source_id: String,
          target_id: String,
          block: T.proc.params(arg0: Node, arg1: Node).void
        ).void
      end
      def with_source_and_target(source_id, target_id, &block)
        yield(fetch_node(:source, source_id), fetch_node(:target, target_id))
      end

      sig { params(type: Symbol, id: String).returns(Node) }
      def fetch_node(type, id)
        @nodes.fetch(id) do
          raise ArgumentError,
                "Could not find #{type} #{id.inspect} in #{@nodes.keys.inspect}"
        end
      end

      sig do
        params(
          node: Node,
          direction: Direction,
          block: T.proc.params(arg0: Node).void
        ).void
      end
      def dfs(node, direction, &block)
        node
          .send(direction.serialize)
          .each { |id| dfs(@nodes.fetch(id), direction, &block) }

        yield node
      end
    end
  end
end

# if __FILE__ == $0
#   graph = Resources::DependencyGraph.new
#
#   graph.add_node("a")
#   graph.add_node("b")
#   graph.add_node("c")
#
#   p graph.size
#
#   graph.add_dependency("a", "b")
#   graph.add_dependency("b", "c")
#   p graph.dependencies_of("a")
#   p graph.dependencies_of("b")
#   p graph.dependants_of("c")
#   p graph.overall_order
#   p graph.overall_order(only_leaves: true)
# end
