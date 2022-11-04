# typed: strict
# frozen_string_literal: true

require "base64"
require "digest/sha2"
require "crass"
require_relative "css/transformer"
require_relative "css/formatter"

module Mayu
  module Resources
    module Transformers
      module CSS
        class TransformResult < T::Struct
          const :filename, String
          const :output, String
          const :content_hash, String
          const :layer_name, String
          const :classes, T::Hash[String, String]
          const :source_map, T::Hash[String, T.untyped]
        end

        extend T::Sig

        sig do
          params(
            source: String,
            source_path: String,
            source_line: Integer,
            content_hash: T.nilable(String)
          ).returns(TransformResult)
        end
        def self.transform(
          source:,
          source_path:,
          source_line: 1,
          content_hash: nil
        )
          source_path_without_extension =
            File.join(
              File.dirname(source_path),
              File.basename(source_path, ".*")
            ).delete_prefix("./")

          content_hash ||=
            Digest::SHA256.hexdigest(
              [source_path_without_extension, source].inspect
            )[
              0..7
            ]

          transformer =
            CSS::Transformer.new(
              path: source_path_without_extension,
              content_hash: content_hash
            )

          output =
            source
              .then { Crass.parse(_1) }
              .then { transformer.transform(_1) }
              .then { Formatter.format_ast(_1) }

          header = "/* #{source_path} */\n"

          content_hash = Digest::SHA256.digest(output)
          urlsafe_hash = Base64.urlsafe_encode64(content_hash)
          filename = "#{urlsafe_hash}.css"
          layer_name = "mayu-#{urlsafe_hash.gsub(/[^A-Za-z0-9-_]/, "")}"
          output =
            "@layer #{escape_string(transformer.layer_name)} {\n#{output}\n}"

          TransformResult.new(
            filename:,
            output:,
            layer_name: transformer.layer_name,
            classes: transformer.classes,
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
