# typed: strict

require_relative "component_module"
require_relative "css"
require_relative "dependency_graph"
require_relative "code_reloader"

module Mayu
  module Modules
    class System
      extend T::Sig

      class ResolveError < StandardError ; end

      ModuleType = T.type_alias { T.any(ComponentModule, CSS::Base) }

      sig{returns(String)}
      attr_reader :root
      sig {returns(DependencyGraph)}
      attr_reader :dependency_graph
      sig {returns(CodeReloader)}
      attr_reader :code_reloader

      sig { params(root: String).void }
      def initialize(root)
        @root = T.let(File.expand_path(root), String)
        @modules = T.let({}, T::Hash[String, ModuleType])
        @dependency_graph = T.let(DependencyGraph.new, DependencyGraph)
        @code_reloader = T.let(CodeReloader.new(self), CodeReloader)

        @code_reloader.start
      end

      sig {params(source: String, target: String).void}
      def add_dependency(source, target)
        @dependency_graph.add_dependency(source, target)
      end

      sig { params(path: String, source_path: String).returns(ComponentModule) }
      def load_page(path, source_path = "/")
        puts "LOADING PAGE #{path}"
        resolve_path('app', path, source_path) => [full_path, resolved_path]

        @dependency_graph.add_node(full_path)

        T.cast(@modules[full_path] ||= ComponentModule.new(
          self,
          resolved_path,
          full_path,
          File.read(full_path)
        ), Mayu::Modules::ComponentModule)
      end

      sig { params(path: String, source_path: String).returns(ComponentModule) }
      def load_component(path, source_path = "/")
        resolve_path('components', path, source_path) => [full_path, resolved_path]

        @dependency_graph.add_node(full_path)

        T.cast(@modules[full_path] ||= ComponentModule.new(
          self,
          resolved_path,
          full_path,
          File.read(full_path)
        ), Mayu::Modules::ComponentModule)
      end

      sig { params(subdir: String, path: String, source_path: String).returns([String, String]) }
      def resolve_path(subdir, path, source_path = "/")
        resolved_path = File.expand_path(path, File.dirname(source_path)).sub(/(\.mayu)?$/, ".mayu")
        full_path = File.join(@root, subdir, resolved_path)

        if File.file?(full_path)
          [full_path, resolved_path]
        else
          raise ResolveError,
            "Could not find #{full_path} in #{@root}"
        end
      end

      sig {params(path: String).void}
      def remove_module(path)
        puts "\e[31mRemoving module #{path}\e[0m"
        @dependency_graph.remove_node(path)
      end

      sig {params(full_path: String).returns(T::Boolean)}
      def reload_module(full_path)
        return false unless full_path.end_with?(".mayu")
        return false unless @dependency_graph.has_node?(full_path)

        old_module = @modules.delete(full_path)
        return false unless old_module

        puts "\e[33mReloading module #{full_path}\e[0m"

        resolved_path = full_path[(@root.length)..-1].to_s.split("/").slice(1..-1).to_a.join("/")

        component_module = ComponentModule.new(
          self,
          resolved_path,
          full_path,
          File.read(full_path)
        )

        @dependency_graph.direct_dependants_of(full_path).each do |dependant|
          dep = @modules[dependant]

          if dep.is_a?(Mayu::Modules::ComponentModule)
            dep.klass.constants.each do |const|
              value = dep.klass.const_get(const)
              if value == old_module
                puts "\e[35mUpdating #{const} in #{dep}\e[0m"
                dep.klass.const_set(const, component_module)
              end
            end
          end
        end

        @modules[full_path] = component_module

        true
      end

      sig { params(path: String).returns(CSS::Base) }
      def load_css(path)
        # CSS files are always together with their components,
        # just replace the extension.
        CSS.load(path.sub(/\.mayu$/, ".css"))
      end
    end
  end
end
