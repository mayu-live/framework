# typed: true

require "minitest/autorun"
require "test_helper"

require_relative "css"
require_relative "css/rouge_lexer"
require "rouge"

class Mayu::Resources::Transformers::CSS::Test < Minitest::Test
  def test_pseudo_classes
    assert_equal(transform(<<~CSS.strip), <<~CSS.strip)
      *,
      *::before,
      *::after { box-sizing: border-box; }
    CSS
      /* MyComponent */
      *,*::before,*::after{box-sizing:border-box;}
    CSS
  end

  def test_has
    assert_equal(transform(<<~CSS.strip), <<~CSS.strip)
      .formGroup:has(:invalid) {
        --color: var(--invalid);
      }

      .formGroup:has(:invalid:not(:focus)) {
        animation: shake 0.25s;
      }
    CSS
      /* MyComponent */
      .MyComponent\\.formGroup\\?55MG8VU:has(:invalid){--color:var(--invalid);}.MyComponent\\.formGroup\\?55MG8VU:has(:invalid:not(:focus)){animation:shake .25s;}
    CSS
  end

  def test_adjacent_selectors
    skip("https://github.com/ruby-syntax-tree/syntax_tree-css/issues/25")

    assert_equal(transform(<<~CSS.strip), <<~CSS.strip)
      .a + .b { color: #fff; }
    CSS
      /* MyComponent */
    CSS
  end

  private

  def transform(source)
    app_root = File.expand_path(File.join(__dir__, "..", "..", "example"))
    source_path = "MyComponent"
    Mayu::Resources::Transformers::CSS.transform(
      source:,
      source_path:,
      app_root:
    ).output
    # .tap { puts "\e[1mTransformed:\e[0m\n#{_1}" }
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
      app_root: root,
      source_path: path
    )
  end

  def colorize_source(source, lexer)
    theme = Rouge::Themes::Monokai.new
    formatter = Rouge::Formatters::Terminal256.new(theme:)
    formatter.format(lexer.lex(source.chomp))
  end
end
