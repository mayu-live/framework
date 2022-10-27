# typed: true

require "minitest/autorun"
require "test_helper"

require_relative "haml"
require "rouge"

class TestHaml < Minitest::Test
  def test_spacing
    assert_equal(transform_and_format(<<~HAML), <<~RUBY)
      %p
        There should be no space on the left of this text.
        But there should be one between this line and the previous line.
        %a(href="/")< And there should be spaces before this link
        \\. Was there?
    HAML
      def render
        Mayu::VDOM.h(
          :p,
          "There should be no space on the left of this text. But there should be one between this line and the previous line.",
          " ",
          Mayu::VDOM.h(:a, "And there should be spaces before this link", href: "/"),
          ". Was there?"
        )
      end
    RUBY
  end

  def test_spacing2
    assert_equal(transform_and_format(<<~HAML), <<~RUBY)
      %div
        %p Hello World
        %p
          Hello World
        %p
          Hello
          World
        %p

          Hello World
    HAML
      def render
        Mayu::VDOM.h(
          :div,
          Mayu::VDOM.h(:p, "Hello World"),
          Mayu::VDOM.h(:p, "Hello World"),
          Mayu::VDOM.h(:p, "Hello World"),
          Mayu::VDOM.h(:p, "Hello World")
        )
      end
    RUBY
  end

  def test_handlers
    assert_equal(transform_and_format(<<~HAML), <<~RUBY)
      :ruby
        def handle_click(e)
          Console.logger.info(self, e)
        end

      %button(onclick=handle_click) Click me
    HAML
      def handle_click(e)
        Console.logger.info(self, e)
      end

      def render
        Mayu::VDOM.h(:button, "Click me", **{ onclick: handler(:handle_click) })
      end
    RUBY
  end

  def test_transform
    root =
      File.expand_path(File.join(__dir__, "..", "..", "..", "..", "example"))
    path = "app/pages/docs/deployment/page.haml"

    transform_and_format_file(root:, path:)
  end

  def test_early_return
    assert_equal(transform_and_format(<<~HAML), <<~RUBY)
    - if true
      - return
        .foo
    .bar
    HAML
    def render
      if true
        return(
          begin
            Mayu::VDOM.h(:div, class: styles[:foo])
          end
        )
      end
      Mayu::VDOM.h(:div, class: styles[:bar])
    end
    RUBY
  end

  def test_class_names
    assert_equal(transform_and_format(<<~HAML), <<~RUBY)
    :ruby
      lol = "lol"
      id = "check123"
      props = { label: "label", asd: "asd" }

    %div.foo(class="bar" asdd=lol){class: "baz"}
      = "hello"
      %input(id=id){
        class: classname,
        type: "checkbox",
        placeholder: props[:label],
        **props.except(:label),
      }
    HAML
    lol = "lol"
    id = "check123"
    props = { label: "label", asd: "asd" }

    def render
      Mayu::VDOM.h(
        :div,
        "hello",
        Mayu::VDOM.h(
          :input,
          **{ id: id },
          **{
            type: "checkbox",
            placeholder: props[:label],
            **props.except(:label)
          },
          class: styles[classname]
        ),
        **{ asdd: lol },
        class: styles[:foo, :bar, "baz"]
      )
    end
    RUBY
  end

  private

  def transform_and_format_file(root:, path:)
    transform_and_format(File.read(File.join(root, path)))
  end

  def transform_and_format(haml)
    transformed = Mayu::Resources::Transformers::Haml.to_ruby(haml)

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

    puts <<~EOF
    #{e.message} on line #{e.lineno} col #{e.column}
    #{formatted_source}
    EOF
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
