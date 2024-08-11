# frozen_string_literal: true
#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "minitest/autorun"

require_relative "backtrace_rewriter"
require_relative "source_map"

class Mayu::Modules::BacktraceRewriter::Test < Minitest::Test
  BacktraceRewriter = Mayu::Modules::BacktraceRewriter
  SourceMap = Mayu::Modules::SourceMap

  FakeMod = Data.define(:source_map)

  def test_rewrite_exception
    source_map = SourceMap::SourceMap.parse(<<~INPUT, <<~OUTPUT)
        :ruby
          def hello
            raise "asd"
          end
        %div
          %p= hello
      INPUT
        class MyComponent
          # #{SourceMap::Mark[2, "def hello"]}
          def hello
            # #{SourceMap::Mark[3, 'raise "asd"']}
            raise "asd"
          end
          def render
            H[:div,
              H[:p
                # #{SourceMap::Mark[6, "hello"]}
                hello
              ]
            ]
          end
        end
      OUTPUT

    expected = <<~BACKTRACE.lines.map(&:strip)
        /app/components/MyComponent.haml:3:in `render'
        /app/components/MyComponent.haml:6:in `render'
        /vendor/mayu/hello.rb:123:in `update'
      BACKTRACE

    backtrace_rewriter =
      BacktraceRewriter.new(
        { "/app/components/MyComponent.haml" => FakeMod.new(source_map) }
      )

    actual =
      backtrace_rewriter.rewrite_backtrace(<<~BACKTRACE.lines.map(&:strip))
        /app/components/MyComponent.haml:5:in `render'
        /app/components/MyComponent.haml:11:in `render'
        /vendor/mayu/hello.rb:123:in `update'
      BACKTRACE

    assert_equal(expected, actual)
  end

  def test_format_exception
    source_map = SourceMap::SourceMap.parse(<<~INPUT, <<~OUTPUT)
        :ruby
          def hello
            raise "asd"
          end
        %div
          %p= hello
      INPUT
        class MyComponent
          # #{SourceMap::Mark[2, "def hello"]}
          def hello
            # #{SourceMap::Mark[3, 'raise "asd"']}
            raise "asd"
          end
          def render
            H[:div,
              H[:p
                # #{SourceMap::Mark[6, "hello"]}
                hello
              ]
            ]
          end
        end
      OUTPUT

    e = StandardError.new("Something went wrong")

    e.set_backtrace(
      [
        "/app/components/MyComponent.haml:3:in `render'",
        "/app/components/MyComponent.haml:6:in `render'",
        "/vendor/mayu/hello.rb:123:in `update'"
      ]
    )

    backtrace_rewriter =
      BacktraceRewriter.new(
        { "/app/components/MyComponent.haml" => FakeMod.new(source_map) }
      )

    puts backtrace_rewriter.format_exception(e)
  end
end
