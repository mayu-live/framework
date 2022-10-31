# typed: strict
# frozen_string_literal: true

require "syntax_tree/xml"

module Mayu
  module TestHelper
    module Formatting
      Lexers =
        T.type_alias do
          T.any(Rouge::Lexers::Ruby, Rouge::Lexers::Haml, Rouge::Lexers::HTML)
        end

      class << self
        extend T::Sig

        sig { params(xml: String).returns(String) }
        def format_xml_plain(xml)
          SyntaxTree::XML.format(xml)
        end

        sig { params(source: String, language: Symbol).returns(String) }
        def format_source(source, language)
          case language
          when :ruby
            Formatting.format_ruby(source)
          when :haml
            Formatting.format_haml(source)
          when :html
            Formatting.format_html(source)
          else
            raise ArgumentError, "Don't know how to format #{language}"
          end
        end

        sig { params(haml: String).returns(String) }
        def format_haml(haml)
          prepend_line_numbers_and_colorize_source(
            haml,
            Rouge::Lexers::Haml.new
          )
        end

        sig { params(html: String).returns(String) }
        def format_html(html)
          prepend_line_numbers_and_colorize_source(
            SyntaxTree::XML.format(html),
            Rouge::Lexers::HTML.new
          )
        end

        sig { params(ruby: String).returns(String) }
        def format_ruby(ruby)
          prepend_line_numbers_and_colorize_source(
            SyntaxTree::XML.format(ruby),
            Rouge::Lexers::HTML.new
          )
        end

        sig do
          type_parameters(:R)
            .params(source: String, block: T.proc.returns(T.type_parameter(:R)))
            .returns(T.type_parameter(:R))
        end
        def handle_parse_error(source, &block)
          yield
        rescue SyntaxTree::Parser::ParseError => e
          start_line = [0, 0].max
          formatted_source =
            prepend_line_numbers(
              extract_lines(source.to_s, start_line, -1),
              start_line: start_line + 1,
              error_line: e.lineno
            ).join

          Console.logger.error(self, <<~ERROR)
            #{e.message} on line #{e.lineno} col #{e.column}
            #{formatted_source}
          ERROR

          raise
        end

        sig do
          params(str: String, from: Integer, to: Integer).returns(
            T::Array[String]
          )
        end
        def extract_lines(str, from, to)
          str.each_line.to_a[from..to] || []
        end

        sig { params(source: String, lexer: Lexers).returns(String) }
        def prepend_line_numbers_and_colorize_source(source, lexer)
          prepend_line_numbers(
            colorize_source(source, Rouge::Lexers::HTML.new).each_line
          ).join
        end

        sig { params(source: String, lexer: Lexers).returns(String) }
        def colorize_source(source, lexer)
          theme = Rouge::Themes::Monokai.new
          formatter = Rouge::Formatters::Terminal256.new(theme:)
          formatter.format(lexer.lex(source.chomp))
        end

        sig do
          params(
            lines: T::Enumerable[String],
            start_line: Integer,
            error_line: T.nilable(Integer)
          ).returns(T::Array[String])
        end
        def prepend_line_numbers(lines, start_line: 1, error_line: nil)
          number_format = "\e[38;5;250;48;5;236m%3d \e[0m"
          error_format = "\e[41m%s\e[0m"

          lines
            .map
            .with_index(start_line) do |line, i|
              if error_line == i
                format(error_format, line.chomp) + "\n"
              else
                line
              end.prepend(format(number_format, i))
            end
        end
      end
    end
  end
end
