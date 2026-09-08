# frozen_string_literal: true
#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "samovar"

module Mayu
  module Commands
    class Transform < Samovar::Command
      self.description = "Inspect a Klenod-transformed module"

      options do
        option "--no-line-numbers", "Disable line numbers", default: false
        option "--no-colors", "Disable syntax highlighting", default: false
      end

      one :path, "Path to file to transform", required: true

      def call
        require "rouge"
        require_relative "../configuration"
        require_relative "../klenod"

        Configuration.with(:development) do |config|
          transform_with_klenod(
            Klenod::Configuration.load(root: config.root),
            @path,
            line_numbers: !@options[:no_line_numbers],
            colors: !@options[:no_colors]
          )
        end
      end

      private

      def transform_with_klenod(configuration, path, line_numbers:, colors:)
        source_path = Pathname.new(path).expand_path
        relative_path =
          source_path.relative_path_from(
            Pathname.new(configuration.source_path)
          ).to_s
        record = configuration.context.entry(relative_path).record
        formatter = CodeFormatter.new(line_numbers:, colors:)
        lexer =
          Rouge::Lexer.find_fancy(
            File.extname(source_path).delete_prefix("."),
            Rouge::Lexers::PlainText
          )

        puts "\e[1;3mInput:\e[0;2m #{relative_path}\e[0m"
        puts formatter.format(File.read(source_path).strip, lexer)
        puts "\e[1;3mOutput:\e[0m"
        puts formatter.format(
               record.transformed_source.strip,
               Rouge::Lexers::Ruby
             )
        return if record.assets.empty?

        puts "\e[1;3mAssets:\e[0m"
        record.assets.each do |asset|
          puts "#{asset.output_path} #{asset.content_type}"
        end
      rescue ArgumentError
        raise ArgumentError,
              "#{path} must be inside #{configuration.source_path}"
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
            .then { colorize(it, lexer) }
            .then { prepend_line_numbers(it) }
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
      end
    end
  end
end
