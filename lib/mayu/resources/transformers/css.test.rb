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
      @layer app\\/components\\/MyComponent\\?abc123 {
      *,
      *::before,
      *::after { box-sizing: border-box; }
      }
    CSS
  end

  def test_media_queries
    assert_equal(transform(<<~CSS.strip), <<~CSS.strip)
      @media (min-width: 8em) and (max-width: 32em) {
      .foo { color: fuchsia; }
      }
      .bar { color: blue; }
    CSS
      @layer app\\/components\\/MyComponent\\?abc123 {
      @media (min-width: 8em) and (max-width: 32em) {
      .app\\/components\\/MyComponent\\.foo\\?abc123 { color: fuchsia; }
      }
      .app\\/components\\/MyComponent\\.bar\\?abc123 { color: blue; }
      }
    CSS
  end

  def test_element_selectors
    assert_equal(transform(<<~CSS.strip), <<~CSS.strip)
      p { color: fuchsia; }
    CSS
      @layer app\\/components\\/MyComponent\\?abc123 {
      .app\\/components\\/MyComponent_p\\?abc123 { color: fuchsia; }
      }
    CSS
  end

  def test_composes
    assert_equal(transform(<<~CSS.strip), <<~CSS.strip)
      .foo {
        color: #f0f;
      }
      .bar {
        composes: foo;
      }
    CSS
      @layer app\\/components\\/MyComponent\\?abc123 {
      .app\\/components\\/MyComponent\\.foo\\?abc123 {
        color: #f0f;
      }
      .app\\/components\\/MyComponent\\.bar\\?abc123 {

      }
      }
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
      @layer app\\/components\\/MyComponent\\?abc123 {
      .app\\/components\\/MyComponent\\.formGroup\\?abc123:has(:invalid) {
        --color: var(--invalid);
      }

      .app\\/components\\/MyComponent\\.formGroup\\?abc123:has(:invalid:not(:focus)) {
        animation: shake 0.25s;
      }
      }
    CSS
  end

  def test_attributes
    assert_equal(transform(<<~CSS.strip), <<~CSS.strip)
      .page[aria-current="page"] {
        background: var(--blue);
      }
    CSS
      @layer app\\/components\\/MyComponent\\?abc123 {
      .app\\/components\\/MyComponent\\.page\\?abc123[aria-current=\"page\"] {
        background: var(--blue);
      }
      }
    CSS
  end

  def test_adjacent_selectors
    assert_equal(transform(<<~CSS.strip), <<~CSS.strip)
      a + .b { color: #fff; }
    CSS
      @layer app\\/components\\/MyComponent\\?abc123 {
      .app\\/components\\/MyComponent_a\\?abc123 + .app\\/components\\/MyComponent\\.b\\?abc123 { color: #fff; }
      }
    CSS
  end

  private

  def transform(source)
    source_path = "app/components/MyComponent"
    content_hash = "abc123"

    Mayu::Resources::Transformers::CSS
      .transform(source:, source_path:, content_hash:)
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
