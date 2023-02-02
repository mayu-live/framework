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
            source_line: Integer
          ).returns(TransformResult)
        end
        def self.transform(source:, source_path:, source_line: 1)
          # Required here because it's not necessary in production..
          # kinda messy. need to rewrite the entire "resources" thing...
          require "mayucss"

          source_path_without_extension =
            File.join(
              File.dirname(source_path),
              File.basename(source_path, ".*")
            ).delete_prefix("./")

          result = MayuCSS.transform(source_path_without_extension, source)

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
            classes: {
              **result.classes.transform_keys(&:to_sym),
              **result.elements.transform_keys { :"__#{_1}" }
            }.freeze,
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

        sig { params(str: String).returns(String) }
        def self.escape_string(str)
          str.gsub(/[^\w-]/, '\\\\\0')
        end
      end
    end
  end
end
