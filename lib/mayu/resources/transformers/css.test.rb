# typed: true

require "minitest/autorun"
require "test_helper"

require_relative "css"
require_relative "css/rouge_lexer"
require "rouge"

class Mayu::Resources::Transformers::CSS::Test < Minitest::Test
  EXAMPLES_ROOT = File.join(__dir__, "__test__", "css")

  Dir[File.join(EXAMPLES_ROOT, "*.in.css")].each do |input_path|
    basename = File.basename(input_path, ".in.css")

    if ENV["MATCH"] in String => match
      next unless basename.include?(match)
    end

    skip_path = File.join(EXAMPLES_ROOT, "#{basename}.skip")
    output_path = File.join(EXAMPLES_ROOT, "#{basename}.out.css")

    input = File.read(input_path)
    expected = File.read(output_path)

    define_method(:"test_#{basename}") do
      T.bind(self, Mayu::Resources::Transformers::CSS::Test)

      skip File.read(skip_path) if File.exist?(skip_path)
      actual = transform(input)
      # File.write(output_path, actual)
      assert_equal(expected, actual)
    end
  end

  private

  def transform(source)
    source_path = "app/components/MyComponent"

    Mayu::Resources::Transformers::CSS
      .transform(source:, source_path:)
      .output
      .each_line
      .map(&:rstrip)
      .join("\n")
      .tap do
        puts(
          "\e[1mTransformed:\e[0m",
          prepend_line_numbers(
            colorize_source(
              _1.strip,
              Mayu::Resources::Transformers::CSS::RougeLexer.new
            ).each_line
          )
        )
      end
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

  def transform_file(root:, path:)
    Mayu::Resources::Transformers::CSS.transform(
      source: File.read(File.join(root, path)),
      source_path: path
    )
  end

  def colorize_source(source, lexer)
    theme = Rouge::Themes::Monokai.new
    formatter = Rouge::Formatters::Terminal256.new(theme:)
    formatter.format(lexer.lex(source.chomp))
  end
end
