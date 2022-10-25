# typed: strict

require "brotli"
require_relative "../transformers/css"

module Mayu
  module Resources
    module Types
      class Stylesheet < Base
        class ClassnameProxy
          extend T::Sig

          sig { params(stylesheet: Stylesheet).void }
          def initialize(stylesheet)
            @stylesheet = stylesheet
          end

          sig { params(ident: Symbol).returns(String) }
          def method_missing(ident)
            @stylesheet.classes[ident.to_s].to_s
          end

          sig { params(args: T.untyped).returns(String) }
          def [](*args)
            args
              .each_with_object(Set.new) { |arg, set| add_to_result(set, arg) }
              .join(" ")
          end

          private

          sig { params(result: T::Set[String], arg: T.untyped).void }
          def add_to_result(result, arg)
            case arg
            when Symbol
              if klass = @stylesheet.classes[arg.to_s]
                result.add(klass)
              end
            when String
              result.add(arg)
            when Array
              arg.each { add_to_result(result, _1) }
            when Hash
              arg.each { add_to_result(result, _1) if _2 }
            end
          end
        end

        extend T::Sig

        sig { returns(T::Hash[String, String]) }
        attr_reader :classes

        sig { params(resource: Resource).void }
        def initialize(resource)
          super
          klasses = {}

          transform_result =
            Transformers::CSS.transform(
              app_root: resource.app_root,
              source: resource.read(encoding: "utf-8"),
              source_path: resource.path
            )

          transform_result.classes

          @source = T.let(transform_result.output, String)
          @content_hash = T.let(transform_result.content_hash, String)
          @classes = T.let(transform_result.classes, T::Hash[String, String])
          @filename = T.let(transform_result.filename, String)
          @source_map =
            T.let(transform_result.source_map, T::Hash[String, T.untyped])
        end

        sig { returns(ClassnameProxy) }
        def classname_proxy
          ClassnameProxy.new(self)
        end

        sig { returns(T::Array[Asset]) }
        def assets
          [Asset.new(@filename)]
        end

        sig { params(asset_dir: String).returns(T::Array[Asset]) }
        def generate_assets(asset_dir)
          source_map_link = "\n/*# sourceMappingURL=#{@filename}.map */\n"

          [
            Asset
              .new(@filename)
              .tap do
                _1.generate(
                  asset_dir,
                  @source + source_map_link,
                  compress: true
                )
              end,
            Asset
              .new(@filename + ".map")
              .tap do
                _1.generate(
                  asset_dir,
                  JSON.generate(@source_map),
                  compress: true
                )
              end
          ]
        end

        MarshalFormat =
          T.type_alias { [T::Hash[String, String], String, String, String] }

        sig { returns(MarshalFormat) }
        def marshal_dump
          [@classes, @source, @content_hash, @filename]
        end

        sig { params(args: MarshalFormat).void }
        def marshal_load(args)
          @classes, @source, @content_hash, @filename = args
        end
      end
    end
  end
end
