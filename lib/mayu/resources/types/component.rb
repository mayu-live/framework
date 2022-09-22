# frozen_string_literal: true
# typed: strict

require_relative "base"

module Mayu
  module Resources
    module Types
      class Component < Base
        module LoaderUtils
          extend T::Sig

          sig { params(mod: Module, resource: Resources::Resource).void }
          def self.define_require(mod, resource)
            mod.instance_exec(resource) do |resource|
              define_singleton_method(:__resource) { resource }

              sig { params(path: String).returns(Component) }
              def self.require(path)
                __resource.require(path) => Component => impl
                impl
              end

              sig { params(path: String).returns(Image) }
              def self.image(path)
                __resource.require(path) => Image => impl
                impl
              end
            end
          end
        end

        class ComponentBase
          extend T::Sig

          sig { returns(T.untyped) }
          def render
          end
        end

        extend T::Sig

        sig { params(resource: Resource).void }
        def initialize(resource)
          @resource = resource
          source = T.let(resource.read(encoding: "utf-8"), String)

          @source = T.let(source, String)
          @component = T.let(nil, T.nilable(T.class_of(ComponentBase)))
        end

        sig { returns(T.class_of(ComponentBase)) }
        def component
          @component ||= setup_component
        end

        sig { returns(T.class_of(ComponentBase)) }
        def setup_component
          impl = T.cast(Class.new(ComponentBase), T.class_of(ComponentBase))

          LoaderUtils.define_require(impl, @resource)

          begin
            impl.class_eval(@source, @resource.path, 1)
          rescue => e
            backtrace =
              [*e.backtrace].reject { _1.include?("/gems/sorbet-runtime-") }
                .join("\n")
            $stderr.puts "\e[31mError loading #{@resource.path}: #{e.message}\n\e[33m#{backtrace}\e[0m"
            raise
          end

          styles =
            @resource.registry.add_resource(@resource.path.sub(/\.rb$/, ".css"))
          @resource.registry.dependency_graph.add_dependency(
            @resource.path,
            styles.path
          )
          impl.const_set(:Styles, styles)
          impl
        end

        MarshalFormat = T.type_alias { [String] }

        sig { returns(MarshalFormat) }
        def marshal_dump
          [@source]
        end

        sig { params(args: MarshalFormat).void }
        def marshal_load(args)
          @source = args.first
        end
      end
    end
  end
end
