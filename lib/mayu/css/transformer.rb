# typed: strict
# frozen_string_literal: true

require "pry"
require "syntax_tree/css"
require "source_map"

class SyntaxTree::CSS::Node
  extend T::Sig

  sig { returns(Symbol) }
  def type = self.class.to_s.to_sym
end

module Mayu
  module CSS
    class Transformer < SyntaxTree::CSS::Visitor
      extend T::Sig

      SourceMappingValue =
        T.type_alias { T.any(Integer, { pos: Integer, name: String }) }

      sig { returns(T::Hash[String, String]) }
      attr_reader :classes

      sig { params(source_path: String, out: StringIO).void }
      def initialize(source_path, out)
        @out = out

        @classes =
          T.let(
            Hash.new do |h, k|
              hash =
                Base64.urlsafe_encode64(
                  Digest::SHA256.digest([source_path, k].inspect)
                ).slice(0, 7)
              h[k] = "#{source_path}.#{k}?#{hash}"
            end,
            T::Hash[String, String]
          )

        @mappings = T.let({}, T::Hash[Integer, SourceMappingValue])
      end

      sig do
        params(
          source: String,
          source_path: String,
          app_root: String,
          filename: String,
          offset: Integer,
          source_line: Integer
        ).returns(T::Hash[String, T.untyped])
      end
      def generate_source_map(
        source:,
        source_path:,
        app_root:,
        filename:,
        offset: 0,
        source_line: 1
      )
        map = SourceMap.new(file: filename, source_root: "mayu://")

        source
          .each_line
          .with_index(source_line) do |line, source_line|
            length = line.length

            @mappings.each do |source_pos, target|
              case target
              in Integer => pos
                target_pos = pos
                name = nil
              in { pos:, name: asd }
                target_pos = pos
                name = asd
              end

              next if source_pos < offset
              next if source_pos - length < offset

              map.add_mapping(
                generated_line: 1,
                generated_col: target_pos,
                source_line: source_line,
                source_col: source_pos - offset,
                source: source_path,
                name:
              )
            end

            offset += length
          end

        map.as_json
      end

      sig { params(node: SyntaxTree::CSS::Node).void }
      def visit(node)
        if node.respond_to?(:location)
          @mappings[node.send(:location).start_char] ||= @out.pos
        end

        super(node)
      end

      sig { params(node: SyntaxTree::CSS::CSSStyleSheet).void }
      def visit_css_stylesheet(node)
        node.rules.each { visit(_1) }
      end

      sig { params(node: SyntaxTree::CSS::HashToken).void }
      def visit_hash_token(node)
        @out << "##{node.value}"
      end

      sig { params(node: SyntaxTree::CSS::Selectors::TypeSelector).void }
      def visit_type_selector(node)
        case node.value
        when String
          encode_class(node.value)
        when SyntaxTree::CSS::DelimToken
          node.value.value
        else
          raise
        end
      end

      sig { params(node: SyntaxTree::CSS::StyleRule).void }
      def visit_style_rule(node)
        node.selectors.each_with_index do |selector, i|
          @out << "," unless i.zero?

          case selector
          when SyntaxTree::CSS::Selectors::CompoundSelector
            visit_compound_selector(selector)
          else
            visit(selector)
          end
        end

        @out << "{"
        node.declarations.each { visit(_1) }
        @out << "}"
      end

      sig { params(node: SyntaxTree::CSS::IdentToken).void }
      def visit_ident_token(node)
        @out << node.value
      end

      sig { params(node: SyntaxTree::CSS::DimensionToken).void }
      def visit_dimension_token(node)
        # binding.pry if node.unit == "em"
        @out << "#{node.value}#{node.unit}"
      end

      sig { params(node: SyntaxTree::CSS::WhitespaceToken).void }
      def visit_whitespace_token(node)
        node.value.include?("\n") ? @out << "\n" : @out << " "
      end

      sig { params(node: SyntaxTree::CSS::SimpleBlock).void }
      def visit_simple_block(node)
        @out << node.token
        node.child_nodes.each { visit(_1) }
        @out << case node.token
        when "{"
          "}"
        when "("
          ")"
        when "["
          "]"
        end
      end

      sig { params(node: SyntaxTree::CSS::AtRule).void }
      def visit_at_rule(node)
        @out << "@#{node.name}"
        node.child_nodes.each { visit(_1) }
      end

      sig { params(node: SyntaxTree::CSS::DelimToken).void }
      def visit_delim_token(node)
        @out << node.value
      end

      sig { params(node: SyntaxTree::CSS::CommaToken).void }
      def visit_comma_token(node)
        @out << ","
      end

      sig { params(node: SyntaxTree::CSS::ColonToken).void }
      def visit_colon_token(node)
        @out << ":"
      end

      sig { params(node: SyntaxTree::CSS::SemicolonToken).void }
      def visit_semicolon_token(node)
        @out << ";"
      end

      sig { params(node: SyntaxTree::CSS::PercentageToken).void }
      def visit_percentage_token(node)
        @out << "#{node.value}%"
      end

      sig { params(node: SyntaxTree::CSS::StringToken).void }
      def visit_string_token(node)
        @out << node.value.to_s.inspect
      end

      sig { params(node: SyntaxTree::CSS::NumberToken).void }
      def visit_number_token(node)
        @out << node.value
      end

      sig { params(node: SyntaxTree::CSS::Function).void }
      def visit_function(node)
        @out << "#{node.name}("
        node.value.map { visit(_1) }
        @out << ")"
      end

      sig { params(node: SyntaxTree::CSS::Declaration).void }
      def visit_declaration(node)
        @out << "#{node.name}:"
        node.value.each { |value| visit(value) }
      end

      sig { params(node: SyntaxTree::CSS::Selectors::CompoundSelector).void }
      def visit_compound_selector(node)
        node.subclasses.each_with_index { |subclass, i| visit(subclass) }
      end

      sig { params(node: SyntaxTree::CSS::Selectors::ClassSelector).void }
      def visit_class_selector(node)
        @mappings[node.value.location.start_char] = {
          pos: @out.pos,
          name: node.value.value
        }

        @out << encode_class(node.value.value)
      end

      sig { params(node: SyntaxTree::CSS::Selectors::PseudoClassSelector).void }
      def visit_pseudo_class_selector(node)
        @out << ":"
        visit(node.value)
      end

      sig { params(klass: String).returns(String) }
      def encode_class(klass)
        ".#{@classes[klass].to_s.gsub(/[^a-zA-Z0-9_-]/, '\\\\\0')}"
      end

      sig { params(method: Symbol, node: SyntaxTree::CSS::Node).void }
      def method_missing(method, node)
        Console.logger.error(self, "method_missing: #{method}")
      end
    end
  end
end
