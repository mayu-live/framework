# typed: true

require "minitest/autorun"
require "test_helper"

require_relative "dependency_graph"

class TestDependencyGraph < Minitest::Test
  def test_overall_order
    dg = Mayu::Resources::DependencyGraph.new

    dg.add_node("slice_bread")
    dg.add_node("add_mustard")
    dg.add_node("add_tomatoes")
    dg.add_node("close_sandwich")

    dg.add_dependency("add_mustard", "slice_bread")
    dg.add_dependency("add_tomatoes", "slice_bread")
    dg.add_dependency("close_sandwich", "add_tomatoes")

    assert(
      dg.overall_order ==
        %w[slice_bread add_mustard add_tomatoes close_sandwich]
    )
  end
end
