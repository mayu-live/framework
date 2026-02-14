# frozen_string_literal: true
#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "digest/sha2"
require "syntax_tree"

module Mayu
  module Modules
    class ImportRewriter
      PREFIX = "hash-"
      Result = Data.define(:source, :imports)
      Replacement = Data.define(:start_char, :end_char, :replacement, :resolved)

      class Visitor < SyntaxTree::Visitor
        attr_reader :replacements

        def initialize(rewriter)
          @rewriter = rewriter
          @replacements = []
        end

        def visit_call(node)
          if replacement = @rewriter.rewrite_node(node)
            @replacements << replacement
          end

          super
        end

        def visit_command(node)
          if replacement = @rewriter.rewrite_node(node)
            @replacements << replacement
          end

          super
        end
      end

      def self.hash_for(path) = PREFIX + Digest::SHA256.hexdigest(path)

      def initialize(resolver:, source_path:)
        @resolver = resolver
        @source_path = source_path
      end

      def call(source)
        ast = SyntaxTree.parse(source)
        visitor = Visitor.new(self)
        ast.accept(visitor)

        imports =
          visitor
            .replacements
            .each_with_object({}) do |replacement, result|
              hash = self.class.hash_for(replacement.resolved)

              if result.key?(hash) && result[hash] != replacement.resolved
                raise "Import hash collision for #{replacement.resolved.inspect}"
              end

              result[hash] = replacement.resolved
            end

        rewritten_source = apply_replacements(source, visitor.replacements)

        Result[rewritten_source, imports]
      end

      def rewrite_node(node)
        return unless import_call?(node)

        import_path = import_path_from_node(node)
        return unless import_path

        resolved_path = @resolver.resolve(import_path, source_dir)
        import_hash = self.class.hash_for(resolved_path)

        Replacement[
          node.start_char,
          node.end_char,
          "import(#{import_hash.inspect})",
          resolved_path
        ]
      end

      private

      def source_dir
        File.dirname(@source_path)
      end

      def apply_replacements(source, replacements)
        return source if replacements.empty?

        output = source.dup
        replacements
          .sort_by(&:start_char)
          .reverse_each do |replacement|
            output[
              replacement.start_char...replacement.end_char
            ] = replacement.replacement
          end
        output
      end

      def import_call?(node)
        case node
        in SyntaxTree::CallNode[
             receiver: nil,
             operator: nil,
             message: SyntaxTree::Ident[value: "import"]
           ]
          true
        in SyntaxTree::Command[message: SyntaxTree::Ident[value: "import"]]
          true
        else
          false
        end
      end

      def import_path_from_node(node)
        case node
        in SyntaxTree::CallNode
          extract_static_string(import_arg_from_call(node))
        in SyntaxTree::Command
          extract_static_string(import_arg_from_command(node))
        end
      end

      def import_arg_from_call(node)
        args =
          case node.arguments
          in SyntaxTree::ArgParen[arguments:]
            arguments
          in SyntaxTree::Args
            node.arguments
          else
            return
          end

        return unless args.parts.length == 1

        args.parts.first
      end

      def import_arg_from_command(node)
        args = node.arguments
        return unless args.is_a?(SyntaxTree::Args)
        return unless args.parts.length == 1

        args.parts.first
      end

      def extract_static_string(node)
        case node
        in SyntaxTree::StringLiteral[
             parts: [SyntaxTree::TStringContent[value:]]
           ]
          value
        else
          nil
        end
      end
    end
  end
end
