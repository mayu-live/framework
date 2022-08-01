# typed: true

require "set"
require 'filewatcher'
require "digest/sha2"

class DependencyGraph
  class Node
    attr_reader :incoming
    attr_reader :outgoing

    def initialize
      @incoming = Set.new
      @outgoing = Set.new
    end

    def delete(path)
      @incoming.delete(path)
      @outgoing.delete(path)
    end
  end

  def initialize
    @nodes = {}
  end

  def size = @nodes.size

  def include?(path) = @nodes.include?(path)

  def add_node(path)
    return if @nodes.include?(path)
    @nodes[path] = Node.new
  end

  def remove_node(path)
    return unless @nodes.include?(path)
    @nodes.delete(path)
    @nodes.each { |node| node.delete(path) }
  end

  def add_dependency(source_path, target_path)
    with_source_and_target(source_path, target_path) do |source, target|
      source.outgoing.add(target_path)
      target.incoming.add(source_path)
    end
  end

  def remove_dependency(source_path, target_path)
    with_source_and_target(source_path, target_path) do |source, target|
      source.outgoing.remove(target_path)
      source.incoming.remove(source_path)
    end
  end

  def direct_dependencies_of(path)
    @nodes.fetch(path).outgoing.to_a
  end

  def direct_dependants_of(path)
    @nodes.fetch(path).incoming.to_a
  end

  def dependencies_of(path, started_at = nil, only_leaves: false)
    raise "Circular" if path == started_at

    @nodes.fetch(path).outgoing.map { |dependency|
      dependencies = dependencies_of(dependency, started_at || path)

      if !only_leaves || dependencies.empty?
        dependencies.add(dependency)
      else
        dependencies
      end
    }.reduce(Set.new, &:merge)
  end

  def dependants_of(path, started_at = nil, only_leaves: false)
    raise "Circular" if path == started_at

    @nodes.fetch(path).incoming.map { |dependant|
      dependants = dependants_of(dependant, started_at || path)
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

  private

  def with_source_and_target(source_path, target_path)
    yield @nodes.fetch(source_path), @nodes.fetch(target_path)
  end
end

graph = DependencyGraph.new

graph.add_node("a")
graph.add_node("b")
graph.add_node("c")

p graph.size

graph.add_dependency('a', 'b')
graph.add_dependency('b', 'c')
p graph.dependencies_of('a')
p graph.dependencies_of('b')
p graph.dependants_of('c')
#
# Filewatcher.new(['lib/', 'Rakefile'], every: true).watch do |file|
#   dg.update(file)
# end
