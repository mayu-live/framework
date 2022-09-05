# typed: strict

require "tsort"
require "set"

module Mayu
  module Resources
    class DependencyGraph
      extend T::Sig
      # This is basically a reimplementation of this library:
      # https://github.com/jriecken/dependency-graph

      class Node
        extend T::Sig

        sig { returns(T::Set[String]) }
        attr_reader :incoming
        sig { returns(T::Set[String]) }
        attr_reader :outgoing

        sig { void }
        def initialize
          @incoming = T.let(Set.new, T::Set[String])
          @outgoing = T.let(Set.new, T::Set[String])
        end

        sig { params(id: String).void }
        def delete(id)
          @incoming.delete(id)
          @outgoing.delete(id)
        end

        sig { params(direction: Symbol).returns(T::Set[String]) }
        def nodes_in_direction(direction)
          case direction
          when :incoming
            incoming
          when :outgoing
            outgoing
          else
            raise ArgumentError, "direction should be :incoming or :outgoing"
          end
        end
      end

      extend T::Sig

      sig { void }
      def initialize
        @nodes = T.let({}, T::Hash[String, Node])
      end

      sig { returns(Integer) }
      def size = @nodes.size

      sig { params(id: String).returns(T::Boolean) }
      def include?(id) = @nodes.include?(id)

      sig { params(id: String).void }
      def add_node(id)
        return if @nodes.include?(id)
        @nodes[id] = Node.new
      end

      sig { params(id: String).void }
      def remove_node(id)
        return unless @nodes.include?(id)
        @nodes.delete(id)
        @nodes.each { |node| node.delete(id) }
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
          ->(key, &b) { @nodes.fetch(key).outgoing.each(&b) }
        )
      end

      private

      sig do
        params(
          node: Node,
          direction: Symbol,
          block: T.proc.params(arg0: Node).void
        ).void
      end
      def dfs(node, direction, &block)
        node
          .nodes_in_direction(direction)
          .each { |id| dfs(@nodes.fetch(id), direction, &block) }

        yield node
      end

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
    end
  end
end

if __FILE__ == $0
  graph = Mayu::Resources::DependencyGraph.new

  graph.add_node("a")
  graph.add_node("b")
  graph.add_node("c")

  p graph.size

  graph.add_dependency("a", "b")
  graph.add_dependency("b", "c")
  p graph.dependencies_of("a")
  p graph.dependencies_of("b")
  p graph.dependants_of("c")
  p graph.overall_order
  p graph.overall_order(only_leaves: true)
end
