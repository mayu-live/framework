# frozen_string_literal: true
# typed: strict

require_relative "base"
require_relative "../../component/base"
require_relative "../rux"

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

        extend T::Sig

        ComponentBase = Mayu::Component::Base

        sig { params(resource: Resource).void }
        def initialize(resource)
          @resource = resource

          source = T.let(resource.read(encoding: "utf-8"), String)

          if resource.path.end_with?(".rux")
            source = Rux.to_ruby(source, visitor: RuxVisitor.new)
          end

          @source = T.let(source, String)
          @component = T.let(nil, T.nilable(T.class_of(ComponentBase)))
        end

        sig { returns(T.class_of(ComponentBase)) }
        def component
          @component ||= setup_component
        end

        sig { returns(T.class_of(Mayu::Component::Base)) }
        def setup_component
          impl =
            T.cast(
              Class.new(Mayu::Component::Base),
              T.class_of(Mayu::Component::Base)
            )

          LoaderUtils.define_require(impl, @resource)

          impl.__mayu_resource = @resource

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
            @resource.registry.add_resource(
              @resource.path.sub(/\.\w+\z/, ".css")
            )

          @resource.registry.dependency_graph.add_dependency(
            @resource.path,
            styles.path
          )

          impl.const_set(:Styles, styles)
          classname_proxy = styles.type.classname_proxy

          impl.instance_exec(classname_proxy) do |proxy|
            define_singleton_method(:styles) { classname_proxy }
            define_method(:styles) { classname_proxy }
          end

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
