# frozen_string_literal: true
# typed: strict

require "sorbet-runtime"
require "msgpack"
require_relative "resolver"
require_relative "dependency_graph"
require_relative "resource"
require_relative "types"
require_relative "assets"

MessagePack::DefaultFactory.register_type(0x00, Symbol)

module Mayu
  module Resources
    class Registry
      EXTENSIONS = T.let(["", ".rb", ".haml"].freeze, T::Array[String])

      extend T::Sig

      sig { returns(String) }
      attr_reader :root
      sig { returns(DependencyGraph) }
      attr_reader :dependency_graph

      sig { params(root: String).void }
      def initialize(root:)
        @root = T.let(File.expand_path(root), String)
        @dependency_graph = T.let(DependencyGraph.new, DependencyGraph)
        @resolver =
          T.let(Resolver::FS.new(@root, extensions: EXTENSIONS), Resolver::Base)
        @assets = T.let(Assets.new, T.nilable(Assets))
      end

      sig { params(dumped: String, root: String).returns(Registry) }
      def self.load(dumped, root:)
        MessagePack.unpack(dumped) => { type: "registry", data: String => data }
        registry =
          T.cast(
            Marshal.load(
              data,
              ->(obj) do
                obj.instance_variable_set(:@root, root) if obj.is_a?(Registry)
                obj
              end
            ),
            Registry
          )

        registry
      end

      sig { returns(String) }
      def dump
        MessagePack.pack(type: "registry", data: Marshal.dump(self))
      end

      MarshalFormat = T.type_alias { [String, T::Hash[String, String]] }

      sig { returns(MarshalFormat) }
      def marshal_dump
        [Marshal.dump(@dependency_graph), @resolver.resolved_paths]
      end

      sig { params(args: MarshalFormat).void }
      def marshal_load(args)
        dependency_graph =
          T.cast(
            Marshal.load(
              args[0],
              ->(obj) do
                if obj.is_a?(Resource)
                  obj.instance_variable_set(:@registry, self)
                end
                obj
              end
            ),
            DependencyGraph
          )

        @dependency_graph = dependency_graph
        @resolver = Resolver::Static.new(args[1])
      end

      sig { params(path: String).returns(String) }
      def absolute_path(path)
        File.join(@root, File.expand_path(path, "/"))
      end

      sig { returns(String) }
      def mermaid_url
        @dependency_graph.to_mermaid_url
      end

      sig { params(filename: String, timeout: Integer, task: Async::Task).void }
      def wait_for_asset(filename, timeout: 2, task: Async::Task.current)
        return unless @assets

        task.with_timeout(timeout) { @assets.wait_for(filename) }
      end

      sig do
        params(asset_dir: String, concurrency: Integer).returns(Async::Task)
      end
      def run_asset_generator(asset_dir, concurrency: 4)
        if @assets
          @assets.run(asset_dir, concurrency:)
        else
          raise "Assets can't be generated in production"
        end
      end

      sig do
        params(path: String, visited: T::Set[String], add: T::Boolean).void
      end
      def reload_resource(path, visited: T::Set[String].new, add: false)
        unless @dependency_graph.has_node?(path)
          add_resource(path) if add
          return
        end

        reload_resources(
          [path, *@dependency_graph.dependants_of(path)],
          visited:
        )
      end

      sig { params(path: String, visited: T::Set[String]).void }
      def unload_resource(path, visited: T::Set[String].new)
        return unless @dependency_graph.has_node?(path)

        dependants = @dependency_graph.dependants_of(path)

        Console.logger.info(self, "Unloading resource, #{path}")

        @dependency_graph.delete_node(path)

        reload_resources(dependants, visited:)
      end

      sig { params(path: String, source: String).returns(Resource) }
      def load_resource(path, source = "/")
        resolved_path = @resolver.resolve(path, source)
        add_resource(resolved_path)
      end

      sig { params(path: String).returns(Resource) }
      def add_resource(path)
        if resource = @dependency_graph.get_resource(path)
          return resource
        end

        resource = Resource.new(registry: self, path:)

        @dependency_graph.add_node(resource.path, resource)

        resource.assets.each { |asset| @assets.add(asset) } if @assets

        Console.logger.info(
          self,
          "Loaded #{resource.type.name} from #{resource.path}"
        )
        resource
      end

      private

      sig { params(paths: T::Enumerable[String], visited: T::Set[String]).void }
      def reload_resources(paths, visited:)
        paths
          .select { visited.add?(_1) }
          .map { @dependency_graph.get_resource(_1) }
          .compact
          .each do |resource|
            Console.logger.info(self, "Reloading resource: #{resource.path}")
            @dependency_graph.delete_connections(resource.path)
            resource.load_type
          end
      end
    end
  end
end
