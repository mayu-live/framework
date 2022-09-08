# typed: strict

require_relative "resolver"
require_relative "dependency_graph"
require_relative "resource"

module Mayu
  module Resources
    class System
      extend T::Sig

      PAGES_PATH = "/pages"
      STORES_PATH = "/stores"
      COMPONENTS_PATH = "/components"

      sig { returns(String) }
      attr_reader :root

      sig { params(root: String).void }
      def initialize(root)
        @root = root
        @resolver = T.let(Resolver.new(self), Resolver)
        @dependency_graph = T.let(DependencyGraph.new, DependencyGraph)
        @resources = T.let({}, T::Hash[String, Resource])
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
        load_resource(path, PAGES_PATH)
      end

      sig do
        params(path: String, source_path: String).returns(Components::Base)
      end
      def load_component(path, source_path = COMPONENTS_PATH)
        load_resource(path, source_path).type => Types::Ruby => type
        type.class
      end

      sig { params(path: String, source_path: String).returns(Resource) }
      def load_resource(path, source_path = "/")
        resolved_path = @resolver.resolve(path, source_path)

        @resources[resolved_path] ||= Resource.load(self, resolved_path)
      end
    end
  end
end
