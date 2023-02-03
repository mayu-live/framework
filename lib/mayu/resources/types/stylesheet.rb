# typed: strict

require "brotli"
require_relative "../transformers/css"

module Mayu
  module Resources
    module Types
      class Stylesheet < Base
        Classes = T.type_alias { T::Hash[Symbol, String] }

        class ClassNames
          extend T::Sig

          sig { params(classes: Classes).void }
          def initialize(classes)
            @classes = classes
          end

          sig { params(ident: Symbol).returns(String) }
          def method_missing(ident)
            @classes[ident].to_s
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
              if klass = @classes[arg]
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

        sig { returns(Classes) }
        attr_reader :classes

        sig { params(resource: Resource).void }
        def initialize(resource)
          super
          klasses = {}

          transform_result =
            Transformers::CSS.transform(
              source: resource.read(encoding: "utf-8"),
              source_path: resource.path
            )

          transform_result.classes

          @source = T.let(transform_result.output, String)
          @content_hash = T.let(transform_result.content_hash, String)
          @classes = T.let(transform_result.classes, Classes)
          @filename = T.let(transform_result.filename, String)
          @source_map =
            T.let(transform_result.source_map, T::Hash[String, T.untyped])
          @classnames = T.let(nil, T.nilable(ClassNames))
        end

        sig { returns(ClassNames) }
        def classnames
          @classnames ||= ClassNames.new(self.classes)
        end

        sig { returns(T::Array[Asset]) }
        def assets
          source_map_link = "\n/*# sourceMappingURL=#{@filename}.map */\n"

          [
            Asset.new(
              @filename,
              Generators::WriteFile.new(
                contents: @source + source_map_link,
                compress: true
              )
            ),
            Asset.new(
              @filename + ".map",
              Generators::WriteFile.new(
                contents: JSON.generate(@source_map),
                compress: true
              )
            )
          ]
        end

        MarshalFormat = T.type_alias { [Classes, String, String, String] }

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
