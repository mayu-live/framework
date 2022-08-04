# typed: true

module Mayu
  module Modules
    class DependencyGraph
      extend T::Sig
      # This is basically a reimplementation of this library:
      # https://github.com/jriecken/dependency-graph

      class Node
        extend T::Sig

        attr_reader :incoming
        attr_reader :outgoing

        sig {void}
        def initialize
          @incoming = Set.new
          @outgoing = Set.new
        end

        sig {params(id: String).void}
        def delete(id)
          @incoming.delete(id)
          @outgoing.delete(id)
        end

        sig {params(direction: Symbol).returns(T::Set[String])}
        def nodes_in_direction(direction)
          case direction
          when :incoming then incoming
          when :outgoing then outgoing
          else
            raise ArgumentError, "direction should be :incoming or :outgoing"
          end
        end
      end

      def initialize
        @nodes = {}
      end

      def size = @nodes.size

      def include?(id) = @nodes.include?(id)

      def add_node(id)
        return if @nodes.include?(id)
        @nodes[id] = Node.new
      end

      def remove_node(id)
        return unless @nodes.include?(id)
        @nodes.delete(id)
        @nodes.each { |node| node.delete(id) }
      end

      def has_node?(id)
        @nodes.include?(id)
      end

      def add_dependency(source_id, target_id)
        with_source_and_target(source_id, target_id) do |source, target|
          source.outgoing.add(target_id)
          target.incoming.add(source_id)
        end
      end

      def remove_dependency(source_id, target_id)
        with_source_and_target(source_id, target_id) do |source, target|
          source.outgoing.remove(target_id)
          source.incoming.remove(source_id)
        end
      end

      def direct_dependencies_of(id)
        @nodes.fetch(id).outgoing.to_a
      end

      def direct_dependants_of(id)
        @nodes.fetch(id).incoming.to_a
      end

      def dependencies_of(id, started_at = nil, only_leaves: false)
        raise "Circular" if id == started_at

        @nodes.fetch(id).outgoing.map { |dependency|
          dependencies = dependencies_of(dependency, started_at || id)

          if !only_leaves || dependencies.empty?
            dependencies.add(dependency)
          else
            dependencies
          end
        }.reduce(Set.new, &:merge)
      end

      def dependants_of(id, started_at = nil, only_leaves: false)
        raise "Circular" if id == started_at

        @nodes.fetch(id).incoming.map { |dependant|
          dependants = dependants_of(dependant, started_at || id)
          if !only_leaves || dependants.empty?
            dependants.add(dependant)
          else
            dependants
          end
        }.reduce(Set.new, &:merge)
      end

      def entry_nodes
        @nodes.filter { _2.incoming.empty? }.keys
      end

      def overall_order(only_leaves: true)
      end

      private

      sig {params(node: Node, direction: Symbol, block: T.proc.params(arg0: Node).void).void}
      def dfs(node, direction, &block)
        node.nodes_in_direction(direction).each do |id|
          dfs(@nodes.fetch(id), direction, &block)
        end

        yield node
      end

      def with_source_and_target(source_id, target_id)
        yield(fetch_node(:source, source_id), fetch_node(:target, target_id))
      end

      extend T::Sig

      sig {params(type: Symbol, id: String).returns(Node)}
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
  graph = Mayu::Modules::DependencyGraph.new

  graph.add_node("a")
  graph.add_node("b")
  graph.add_node("c")

  p graph.size

  graph.add_dependency('a', 'b')
  graph.add_dependency('b', 'c')
  p graph.dependencies_of('a')
  p graph.dependencies_of('b')
  p graph.dependants_of('c')
  p graph.overall_order
  p graph.overall_order(only_leaves: true)
end
