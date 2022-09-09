# typed: strict

require_relative "resolver"
require_relative "dependency_graph"
require_relative "resource"
require_relative "../component"

module Mayu
  module Resources
    class System
      extend T::Sig

      PAGES_PATH = "/pages"
      STORES_PATH = "/stores"
      COMPONENTS_PATH = "/components"
      ASSETS_PATH = ".assets"

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
      #
      # sig do
      #   params(path: String, source_path: String).returns(Component::Base)
      # end
      # def load_component(path, source_path = COMPONENTS_PATH)
      #   load_resource(path, source_path).type => Types::Ruby => type
      #   type.class
      # end

      sig { params(resource: Resource).returns(T.nilable(Resource)) }
      def load_css(resource)
        basename = File.basename(resource.path, ".*")
        dirname = File.dirname(resource.path)
        path = File.join(dirname, "#{basename}.css")

        load_resource2(path) if File.exist?(File.join(@root, path))
      end

      sig { params(path: String, source_path: String).returns(Resource) }
      def load_resource(path, source_path = "/")
        load_resource2(@resolver.resolve(path, source_path))
      end

      sig { returns(String) }
      def inspect
        "#<#{self.class.name} @root=#{@root.inspect} resources=#{@resources.size}>"
      end

      private

      sig { params(resolved_path: String).returns(Resource) }
      def load_resource2(resolved_path)
        Console.logger.info("Loading #{resolved_path}")

        @resources[resolved_path] ||= begin
          resource = Resource.load(self, resolved_path)
          puts "Loaded resource #{resource.inspect}"
          resource.type.asset&.generate(root:, outdir: ASSETS_PATH)
          resource
        end
      end
    end
  end
end
