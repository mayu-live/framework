# frozen_string_literal: true

require "rouge"
require_relative "../modules/loaders"

module Mayu
  module Commands
    class Transform
      DEFAULT_LINE_NUMBERS = true
      DEFAULT_COLORS = true

      def self.call(filename)
        transform(File.read(filename), filename)
      end

      def self.transform(
        source,
        path,
        line_numbers: DEFAULT_LINE_NUMBERS,
        colors: DEFAULT_COLORS
      )
        formatter = CodeFormatter.new(line_numbers:, colors:)

        loading_file =
          Mayu::Modules::Loaders::LoadingFile.new(
            root: Dir.pwd,
            path:,
            source:,
            digest: nil
          ).load_source

        puts "\e[1;3mInput:\e[0;2m #{path}\e[0m"
        puts formatter.format(loading_file.source.strip, Rouge::Lexers::Haml)

        loading_file =
          Mayu::Modules::Loaders::Haml[
            component_base_class: "Mayu::Component::Base",
            using: ["Mayu::Component::CSSUnits::Refinements"],
            factory: "H"
          ].call(loading_file)

        puts "\e[1;3mOutput:\e[0m"

        formatter.handle_parse_error(loading_file.source.strip) do
          puts formatter.format(loading_file.source.strip, Rouge::Lexers::Ruby)
        end
      end

      class CodeFormatter
        def initialize(
          line_numbers:,
          colors:,
          theme: Rouge::Themes::Monokai.new
        )
          @line_numbers = line_numbers
          @colors = colors
          @formatter = Rouge::Formatters::Terminal256.new(theme:)
        end

        def format(source, lexer)
          source
            .chomp
            .then { colorize(_1, lexer) }
            .then { prepend_line_numbers(_1) }
        end

        def handle_parse_error(source)
          yield
        rescue SyntaxTree::Parser::ParseError => e
          log_parse_error(source, e)
          raise
        end

        private

        def colorize(source, lexer)
          @colors ? @formatter.format(lexer.lex(source)) : source
        end

        def prepend_line_numbers(lines, start_line: 1, error_line: nil)
          return lines unless @line_numbers

          number_format = "\e[38;5;250;48;5;236m%3d \e[0m"
          error_format = "\e[41m%s\e[0m"

          lines
            .each_line
            .map
            .with_index(start_line) do |line, i|
              if error_line == i
                Kernel.format(error_format, line.chomp) + "\n"
              else
                line
              end.prepend(Kernel.format(number_format, i))
            end
        end

        def extract_lines(str, from, to)
          str.each_line.to_a[from..to] || []
        end

        def log_parse_error(source, e)
          start_line = [0, 0].max
          formatted_source =
            prepend_line_numbers(
              extract_lines(source.to_s, start_line, -1),
              start_line: start_line + 1,
              error_line: e.lineno
            ).join

          puts(<<~ERROR)
            #{e.message} on line #{e.lineno} col #{e.column}
            #{formatted_source}
          ERROR
        end
      end
    end
  end
end
