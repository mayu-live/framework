# typed: strict

require_relative "resolver"
require_relative "dependency_graph"
require_relative "mod"

module Mayu
  module Modules2
    class System
      extend T::Sig

      sig { returns(String) }
      attr_reader :root

      sig { params(root: String).void }
      def initialize(root)
        @root = root
        @resolver = T.let(Resolver.new(self), Resolver)
        @dependency_graph = T.let(DependencyGraph.new, DependencyGraph)
      end

      sig { params(path: String).returns(T.class_of(Component::Base)) }
      def load_page_component(path)
        load_page(path).type => ModuleTypes::Ruby => type
        type.klass
      end

      sig { params(path: String).returns(Mod) }
      def load_page(path)
        load(path, "/app")
      end

      sig { params(path: String, source_path: String).returns(Mod) }
      def load(path, source_path = "/")
        resolved_path = @resolver.resolve(path, source_path)

        Mod.load(self, resolved_path)
      end
    end
  end
end
