# frozen_string_literal: true
# typed: strict

require "sorbet-runtime"
require "minitest/reporters"
require "pry"

Minitest::Reporters.use!(
  Minitest::Reporters::DefaultReporter.new,
  ENV,
  Minitest.backtrace_filter
)

require_relative "lib/mayu/metrics"
require_relative "lib/mayu/app_metrics"
require "syntax_tree/xml"

module Mayu
  class TestHelper
    $metrics ||= Mayu::AppMetrics.setup(Prometheus::Client.registry)

    Lexers =
      T.type_alias do
        T.any(Rouge::Lexers::Ruby, Rouge::Lexers::Haml, Rouge::Lexers::HTML)
      end

    class << self
      extend T::Sig

      sig { returns(Mayu::VDOM::VTree) }
      def setup_vtree
        config =
          Mayu::Configuration.from_hash!(
            {
              "mode" => :test,
              "root" => "/laiehbaleihf",
              "secret_key" => "test"
            }
          )

        environment = Mayu::Environment.new(config, $metrics)

        environment.instance_eval <<~RUBY
          # sig {params(path: String).returns(Mayu::VDOM::Descriptor)}
          def load_root(path)
            Mayu::VDOM::Descriptor.new(:div)
          end

          # sig {params(path: String).returns(NilClass)}
          def match_route(path)
          end
        RUBY

        session = Mayu::Session.new(environment:, path: "/")
        Mayu::VDOM::VTree.new(session:)
      end

      sig { params(source: String).returns(String) }
      def format_xml(source)
        SyntaxTree::XML.format(source)
      end

      sig do
        params(source: String, file: String, line: Integer).returns(
          T.class_of(Mayu::Component::Base)
        )
      end
      def haml_to_component(source, file: __FILE__, line: __LINE__)
        result =
          Mayu::Resources::Transformers::Haml.transform(
            content_hash: "test123",
            source: source,
            source_path:
              Pathname
                .new(file)
                .relative_path_from(File.expand_path(__dir__))
                .to_s,
            source_line: line
          )

        impl =
          T.cast(
            Class.new(Mayu::Component::Base),
            T.class_of(Mayu::Component::Base)
          )
        impl.class_eval(result.output, file, line)

        if css = result.css
          classname_proxy =
            Resources::Types::Stylesheet::ClassnameProxy.new(css.classes)
          impl.instance_exec(classname_proxy) do |classname_proxy|
            define_singleton_method(:styles) { classname_proxy }
            define_method(:styles) { classname_proxy }
          end
        end

        impl
      end

      sig { params(haml: String).returns(String) }
      def format_haml(haml)
        prepend_line_numbers(
          colorize_source(haml, Rouge::Lexers::Haml.new).each_line
        ).join
      end

      sig { params(html: String).returns(String) }
      def format_html(html)
        formatted = format_xml(html)
        prepend_line_numbers(
          colorize_source(formatted, Rouge::Lexers::HTML.new).each_line
        ).join
      end

      sig { params(ruby: String).returns(String) }
      def format_ruby(ruby)
        formatted = SyntaxTree.format(ruby)
        prepend_line_numbers(
          colorize_source(formatted, Rouge::Lexers::Ruby.new).each_line
        ).join("\n")
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
