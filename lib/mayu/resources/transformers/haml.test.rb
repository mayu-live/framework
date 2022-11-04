# typed: true

require "minitest/autorun"
require "test_helper"

require_relative "haml"
require "rouge"

class TestHaml < Minitest::Test
  EXAMPLES_ROOT = File.join(__dir__, "__test__", "haml")

  Dir[File.join(EXAMPLES_ROOT, "*.haml")].each do |input_path|
    basename = File.basename(input_path, ".*")

    skip_path = File.join(EXAMPLES_ROOT, "#{basename}.skip")
    output_path = File.join(EXAMPLES_ROOT, "#{basename}.rb")

    input = File.read(input_path)
    output = File.read(output_path)

    define_method(:"test_#{basename}") do
      T.bind(self, TestHaml)
      skip File.read(skip_path) if File.exist?(skip_path)
      assert_equal(transform_and_format(input), output)
    end
  end

  private

  def transform_and_format_file(root:, path:)
    transform_and_format(File.read(File.join(root, path)))
  end

  def transform_and_format(haml)
    transformed =
      Mayu::Resources::Transformers::Haml.transform(
        source: haml,
        source_path: "app/components/MyComponent.haml",
        content_hash: "abc123"
      ).output

    puts "\e[1mInput:\e[0m"
    puts prepend_line_numbers(
           colorize_source(haml, Rouge::Lexers::Haml.new).each_line
         )
    handle_parse_error(transformed) do
      formatted = SyntaxTree.format(transformed)
      puts "\e[1mOutput:\e[0m"
      puts prepend_line_numbers(
             colorize_source(formatted, Rouge::Lexers::Ruby).each_line
           )
      puts
      formatted
    end
  end

  def handle_parse_error(source)
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

  def extract_lines(str, from, to)
    str.each_line.to_a[from..to] || []
  end

  def colorize_source(source, lexer)
    theme = Rouge::Themes::Monokai.new
    formatter = Rouge::Formatters::Terminal256.new(theme:)
    formatter.format(lexer.lex(source.chomp))
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
