# typed: strict
# frozen_string_literal: true

require "base64"
require "digest/sha2"

module Mayu
  module Resources
    module Transformers
      module CSS
        class TransformResult < T::Struct
          const :filename, String
          const :output, String
          const :content_hash, String
          const :layer_name, String
          const :classes, T::Hash[Symbol, String]
          const :elements, T::Hash[Symbol, String]
          const :source_map, T::Hash[String, T.untyped]
        end

        extend T::Sig

        sig do
          params(transform_results: T::Array[TransformResult]).returns(
            T::Hash[String, String]
          )
        end
        def self.merge_classnames(transform_results)
          classnames = Hash.new { |h, k| h[k] = Set.new }

          transform_results.each do |transform_result|
            transform_result.classes.each do |source, target|
              classnames[source].add(target)
            end
          end

          classnames.transform_values { _1.join(" ") }
        end

        sig do
          params(
            source: String,
            source_path: String,
            source_line: Integer,
            minify: T::Boolean
          ).returns(TransformResult)
        end
        def self.transform(source:, source_path:, source_line: 1, minify: true)
          # Required here because it's not necessary in production..
          # kinda messy. need to rewrite the entire "resources" thing...
          require "mayu/css"

          source_path_without_extension =
            File.join(
              File.dirname(source_path),
              File.basename(source_path, ".*")
            ).delete_prefix("./")

          result =
            Mayu::CSS.transform(source_path_without_extension, source, minify:)

          output = result.code.encode("utf-8")

          header = "/* #{source_path} */\n"

          content_hash = Digest::SHA256.digest(output)
          urlsafe_hash = Base64.urlsafe_encode64(content_hash)
          filename = "#{urlsafe_hash}.css"

          layer_name =
            "#{source_path_without_extension}?#{urlsafe_hash.slice(0, 8)}"

          output = "@layer #{escape_string(layer_name)} {\n#{output}\n}"

          TransformResult.new(
            filename:,
            output:,
            layer_name: layer_name,
            classes:
              join_classes(
                result.classes,
                result.elements,
                result.exports
              ).freeze,
            elements: result.elements.transform_keys(&:to_sym),
            content_hash:,
            source_map: {
              "version" => 3,
              "file" => filename,
              "sourceRoot" => "mayu://",
              "sources" => [source_path],
              "sourcesContent" => [source]
            }
          )
        end

        sig do
          params(
            classes: T::Hash[String, String],
            elements: T::Hash[String, String],
            exports: T::Hash[Symbol, T.untyped]
          ).returns(T::Hash[Symbol, String])
        end
        def self.join_classes(classes, elements, exports)
          {
            **classes
              .transform_values { join_class(_1, exports, classes) }
              .transform_keys(&:to_sym),
            **elements
              .transform_values { join_class(_1, exports, classes) }
              .transform_keys { :"__#{_1}" }
          }
        end

        sig do
          params(
            klass: String,
            exports: T::Hash[String, T.untyped],
            classes: T::Hash[String, String]
          ).returns(String)
        end
        def self.join_class(klass, exports, classes)
          if composes = exports[klass]&.composes
            [
              klass,
              *composes.map do |compose|
                case compose
                in Mayu::CSS::ComposeLocal
                  classes[compose.name.to_sym]
                end
              end
            ].join(" ")
          else
            klass
          end
        end

        sig { params(str: String).returns(String) }
        def self.escape_string(str)
          str.gsub(/[^\w-]/, '\\\\\0')
        end
      end
    end
  end
end
