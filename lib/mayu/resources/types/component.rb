# frozen_string_literal: true
# typed: strict

require_relative "base"
require_relative "../../component/base"
require_relative "../transformers/rux"
require_relative "../transformers/haml"

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

              sig do
                params(path: String).returns(T.class_of(Mayu::Component::Base))
              end
              def self.require(path)
                __resource.require(path) => Component => impl
                impl.component
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

          case File.extname(resource.path)
          when ".rux"
            source = Transformers::Rux.to_ruby(source)
          when ".haml"
            transform_result =
              Transformers::Haml.transform(source:, source_path: resource.path)
            source = transform_result.output

            @inline_css =
              T.let(
                transform_result.css,
                T.nilable(Transformers::CSS::TransformResult)
              )
          end

          @source = T.let(source, String)
          @component = T.let(nil, T.nilable(T.class_of(ComponentBase)))
        end

        sig { returns(T::Array[Asset]) }
        def assets
          [@inline_css && Asset.new(@inline_css.filename)].compact
        end

        sig { params(asset_dir: String).returns(T::Array[Asset]) }
        def generate_assets(asset_dir)
          return [] unless @inline_css

          source_map_link =
            "\n/*# sourceMappingURL=#{@inline_css.filename}.map */\n"

          asset = Asset.new(@inline_css.filename)
          asset.generate(
            asset_dir,
            @inline_css.output + source_map_link,
            compress: true
          )

          map = Asset.new(@inline_css.filename + ".map")

          map.generate(
            asset_dir,
            JSON.generate(@inline_css.source_map),
            compress: true
          )

          [asset, map]
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

          impl.const_set(:INLINE_CSS_ASSETS, assets)

          begin
            $stderr.puts "\e[33m#{@source}\e[0m"
            impl.class_eval(@source, @resource.path, 1)
          rescue => e
            backtrace =
              [*e.backtrace].reject { _1.include?("/gems/sorbet-runtime-") }
                .join("\n")
            $stderr.puts "\e[31mError loading #{@resource.path}: #{e.message}\n\e[33m#{backtrace}\e[0m"
            $stderr.puts "\e[33m#{@source}\e[0m"
            raise "Error parsing #{@resource.absolute_path}"
          end

          styles =
            @resource.registry.add_resource(
              @resource.path.sub(/\.\w+\z/, ".css")
            )

          @resource.registry.dependency_graph.add_dependency(
            @resource.path,
            styles.path
          )

          classes = T.let(Hash.new, T::Hash[String, String])

          if styles.type.is_a?(Types::Stylesheet)
            classes.merge!(styles.type.classes)
            impl.instance_exec(styles) do |styles|
              define_singleton_method(:stylesheet) { styles.type }
            end
          end

          classes.merge!(@inline_css.classes) if @inline_css

          unless classes.empty?
            classname_proxy =
              Resources::Types::Stylesheet::ClassnameProxy.new(classes)
            impl.instance_exec(classname_proxy) do |classname_proxy|
              define_singleton_method(:styles) { classname_proxy }
              define_method(:styles) { classname_proxy }
            end
          end

          impl
        end

        MarshalFormat =
          T.type_alias do
            [String, T.nilable(Transformers::CSS::TransformResult)]
          end

        sig { returns(MarshalFormat) }
        def marshal_dump
          [@source, @inline_css]
        end

        sig { params(args: MarshalFormat).void }
        def marshal_load(args)
          @source, @inline_css = args
        end
      end
    end
  end
end
