# frozen_string_literal: true
# typed: strict

require_relative "base"
require_relative "../../component/base"
require_relative "../transformers/haml"

module Mayu
  module Resources
    module Types
      class Component < Base
        module LoaderUtils
          extend T::Sig

          sig { params(mod: Module, resource: Resources::Resource).void }
          def self.define_import(mod, resource)
            mod.instance_exec(resource) do |resource|
              define_singleton_method(:__resource) { resource }

              sig do
                params(path: String).returns(T.class_of(Mayu::Component::Base))
              end
              def self.import(path)
                __resource.import(path) => Component => impl
                impl.component
              end

              sig { params(path: String).returns(Image) }
              def self.image(path)
                __resource.import(path) => Image => impl
                impl
              end

              sig { params(path: String).returns(SVG) }
              def self.svg(path)
                __resource.import(path) => SVG => impl
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

          original_source = T.let(resource.read(encoding: "utf-8"), String)

          source =
            case File.extname(resource.path)
            when ".haml"
              transform_result =
                Transformers::Haml.transform(
                  source: original_source,
                  source_path: resource.path,
                )
              source = transform_result.output

              @inline_css =
                T.let(
                  transform_result.css,
                  T.nilable(Transformers::CSS::TransformResult),
                )

              source
            else
              original_source
            end

          @source = T.let(source, String)
          @component = T.let(nil, T.nilable(T.class_of(ComponentBase)))
        end

        sig { returns(T::Array[Asset]) }
        def assets
          return [] unless @inline_css

          source_map_link =
            "\n/*# sourceMappingURL=#{@inline_css.filename}.map */\n"

          [
            Asset.new(
              @inline_css.filename,
              Generators::WriteFile.new(
                contents: @inline_css.output + source_map_link,
                compress: true,
              ),
            ),
            Asset.new(
              @inline_css.filename + ".map",
              Generators::WriteFile.new(
                contents: JSON.generate(@inline_css.source_map),
                compress: true,
              ),
            ),
          ]
        end

        sig { returns(T.class_of(ComponentBase)) }
        def component
          @component ||= setup_component
        end

        sig { returns(T.class_of(Mayu::Component::Base)) }
        def setup_component
          impl = Class.new(Mayu::Component::Base)

          LoaderUtils.define_import(impl, @resource)

          impl.__mayu_resource = @resource

          impl.const_set(:INLINE_CSS_ASSETS, assets)
          impl.const_set(:H, Mayu::VDOM::H)

          begin
            # $stderr.puts "\e[33m#{@source}\e[0m"
            impl.class_eval(@source, @resource.path, 1)
          rescue SyntaxTree::Parser::ParseError => e
            $stderr.puts "\e[31mError parsing #{@resource.path}:#{e.lineno} #{e.message}\e[0m"

            puts "Error on line #{e.lineno}"
            @source
              .each_line
              .with_index(1) do |line, lineno|
                if lineno == e.lineno
                  puts "\e[31m#{line.chomp}\e[0m"
                else
                  puts "\e[33m#{line.chomp}\e[0m"
                end
              end
          rescue => e
            backtrace =
              [*e.backtrace].reject { _1.include?("/gems/sorbet-runtime-") }
                .join("\n")
            $stderr.puts "\e[31mError loading #{@resource.path}: #{e.class.name}: #{e.message}\n\e[33m#{backtrace}\e[0m"
            $stderr.puts "\e[33m#{@source}\e[0m"
            raise "Error parsing #{@resource.absolute_path}"
          end

          styles =
            @resource.registry.add_resource(
              @resource.path.sub(/\.\w+\z/, ".css"),
            )

          @resource.registry.dependency_graph.add_dependency(
            @resource.path,
            styles.path,
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
            impl.instance_exec(
              Resources::Types::Stylesheet::ClassnameProxy.new(classes),
            ) do |classname_proxy|
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
