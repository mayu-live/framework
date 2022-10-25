# typed: strict
# frozen_string_literal: true

require "base64"
require "digest/sha2"
require_relative "css/transformer"

module Mayu
  module CSS
    class TransformResult < T::Struct
      const :filename, String
      const :output, String
      const :content_hash, String
      const :classes, T::Hash[String, String]
      const :source_map, T::Hash[String, T.untyped]
    end

    extend T::Sig

    sig do
      params(
        source: String,
        source_path: String,
        app_root: String,
        source_line: Integer
      ).returns(TransformResult)
    end
    def self.transform(source:, source_path:, app_root:, source_line: 1)
      source_path_without_extension =
        File.join(File.dirname(source_path), File.basename(source_path, ".*"))

      ast = SyntaxTree::CSS.parse(source)
      out = StringIO.new
      transformer = Transformer.new(source_path_without_extension, out)
      transformer.visit(ast)

      header = "/* #{source_path} */\n"

      output = out.tap(&:rewind).read.to_s.prepend(header)

      content_hash = Digest::SHA256.digest(output)
      filename = Base64.urlsafe_encode64(content_hash) + ".css"

      TransformResult.new(
        filename:,
        output:,
        classes: { **transformer.classes }.freeze,
        content_hash:,
        source_map:
          transformer.generate_source_map(
            source:,
            source_path:,
            app_root:,
            offset: header.length,
            filename:
          ).merge("sourcesContent" => [source])
      )
    end
  end
end
