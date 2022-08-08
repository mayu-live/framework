# typed: strict

require_relative "component_module"
require_relative "css"
require_relative "dependency_graph"
require_relative "code_reloader"

module Mayu
  module Modules
    class System
      extend T::Sig

      class ResolveError < StandardError
      end

      ModuleType = T.type_alias { T.any(ComponentModule, CSS::Base) }

      sig { returns(String) }
      attr_reader :root
      sig { returns(DependencyGraph) }
      attr_reader :dependency_graph
      sig { returns(T.nilable(CodeReloader)) }
      attr_reader :code_reloader

      COMPONENT_EXTENSION = ".rb"
      COMPONENT_EXTENSION_RE = /\.rb$/
      COMPONENT_EXTENSION_RE2 = /(\.rb)?$/

      sig { params(root: String, enable_code_reloader: T::Boolean).void }
      def initialize(root, enable_code_reloader: false)
        @root = T.let(File.expand_path(root), String)
        @components_root = T.let(File.join(@root, 'components'), String)
        @pages_root = T.let(File.join(@root, 'app'), String)
        @modules = T.let({}, T::Hash[String, ModuleType])
        @dependency_graph = T.let(DependencyGraph.new, DependencyGraph)

        if enable_code_reloader
          @code_reloader = T.let(CodeReloader.new(self), CodeReloader)
          @code_reloader.start
        end
      end

      sig { params(source: String, target: String).void }
      def add_dependency(source, target)
        @dependency_graph.add_dependency(source, target)
      end

      sig { params(path: String).returns(ComponentModule) }
      def load_page(path)
        puts "LOADING PAGE #{path}"
        full_path = resolved_path = File.expand_path(path, @pages_root)

        @dependency_graph.add_node(full_path)

        T.cast(
          @modules[full_path] ||= ComponentModule.new(
            self,
            resolved_path,
            full_path,
            File.read(full_path)
          ),
          Mayu::Modules::ComponentModule
        )
      end

      sig { params(path: String, source_path: String).returns(ComponentModule) }
      def load_component(path, source_path = @components_root)
        full_path = resolve_component(path, source_path)
        resolved_path = full_path

        @dependency_graph.add_node(full_path)

        T.cast(
          @modules[full_path] ||= ComponentModule.new(
            self,
            resolved_path,
            full_path,
            File.read(full_path)
          ),
          Mayu::Modules::ComponentModule
        )
      end

      sig { params(path: String).void }
      def remove_module(path)
        puts "\e[31mRemoving module #{path}\e[0m"
        @dependency_graph.remove_node(path)
      end

      sig { params(full_path: String).returns(T::Boolean) }
      def reload_module(full_path)
        if full_path.end_with?(".css")
          return reload_module(full_path.sub(/\.css$/, COMPONENT_EXTENSION))
        end

        return false unless full_path.end_with?(COMPONENT_EXTENSION)
        return false unless @dependency_graph.has_node?(full_path)

        old_module = @modules.delete(full_path)
        return false unless old_module
        return false unless old_module.is_a?(Mayu::Modules::ComponentModule)

        puts "\e[33mReloading module #{full_path}\e[0m"

        resolved_path =
          full_path[(@root.length)..-1]
            .to_s
            .split("/")
            .slice(1..-1)
            .to_a
            .join("/")

        p [resolved_path:, full_path:]

        component_module =
          ComponentModule.new(
            self,
            resolved_path,
            full_path,
            File.read(full_path)
          )

        # @dependency_graph
        #   .direct_dependants_of(full_path)
        #   .each do |dependant|
        #     dep = @modules[dependant]
        #
        #     if dep.is_a?(Mayu::Modules::ComponentModule)
        #       dep.klass.constants.each do |const|
        #         value = dep.klass.const_get(const)
        #         if value == old_module.klass
        #           puts "\e[35mUpdating #{const} in #{dep}\e[0m"
        #           dep.klass.send(:remove_const, const)
        #           dep.klass.const_set(const, component_module)
        #         end
        #       end
        #     end
        #   end

        @modules[full_path] = component_module

        @dependency_graph.dependants_of(full_path).each do |dependant|
          # TODO: This should only do this once, uh.
          # Now all dependants will be reloaded every time...
          # recursively... which means some will be updated
          # more than once..
          reload_module(dependant)
        end

        true
      end

      sig { params(path: String).returns(CSS::Base) }
      def load_css(path)
        # CSS files are always together with their components,
        # just replace the extension.
        CSS.load(path.sub(COMPONENT_EXTENSION_RE, ".css"))
      end

      private

      sig {params(path: String, source_path: String).returns(String)}
      def resolve_component(path, source_path)
        resolved_path =
          if path.match(/\A\.\.?\//)
            File.expand_path(path, File.dirname(source_path))
          else
            File.expand_path(path, @components_root)
          end

        unless in_valid_directory?(resolved_path)
          raise ResolveError, "Could not resolve #{path} from #{source_path}"
        end

        resolved_path_with_extension = resolved_path.sub(COMPONENT_EXTENSION_RE2, COMPONENT_EXTENSION)

        if File.exist?(resolved_path_with_extension)
          return resolved_path_with_extension
        end

        if File.directory?(resolved_path)
          resolved_path = File.join(resolved_path, File.basename(resolved_path))
        end

        resolved_path_with_extension = resolved_path.sub(COMPONENT_EXTENSION_RE2, COMPONENT_EXTENSION)

        if File.exist?(resolved_path_with_extension)
          return resolved_path_with_extension
        end

        raise ResolveError, "Could not resolve #{path} from #{source_path} (tried #{resolved_path})"
      end

      sig {params(path: String).returns(T::Boolean)}
      def in_valid_directory?(path)
        path.start_with?(@components_root) ||
        path.start_with?(@pages_root)
      end
    end
  end
end
