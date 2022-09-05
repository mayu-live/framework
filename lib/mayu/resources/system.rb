# typed: strict

require_relative "resolver"
require_relative "dependency_graph"
require_relative "mod"

module Mayu
  module Resources
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
      def load_component(path)
        load_page(path).type => Types::Ruby => type
        type.klass
      end

      sig { params(path: String).returns(T.class_of(Component::Base)) }
      def load_page_component(path)
        load_page(path).type => Types::Ruby => type
        type.klass
      end

      sig { params(path: String).returns(Resource) }
      def load_page(path)
        load(path, "/app")
      end

      sig { params(path: String, source_path: String).returns(Resource) }
      def load(path, source_path = "/")
        resolved_path = @resolver.resolve(path, source_path)

        Resource.load(self, resolved_path)
      end
    end
  end
end
