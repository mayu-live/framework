require "minitest/autorun"

require_relative "source_map"

class Mayu::Modules::SourceMap::Test < Minitest::Test
  SourceMap = Mayu::Modules::SourceMap

  def test_parse
    skip
    parsed = SourceMap::SourceMap.parse(<<~INPUT, <<~OUTPUT)
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

    actual =
      parsed.rewrite_backtrace(
        <<~BACKTRACE.lines.map(&:strip),
        /app/components/MyComponent.haml:5:in `render'
        /app/components/MyComponent.haml:11:in `render'
        /vendor/mayu/hello.rb:123:in `update'
      BACKTRACE
        "/app/components/MyComponent.haml",
      )

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

    e.set_backtrace([
      "/app/components/MyComponent.haml:3:in `render'",
      "/app/components/MyComponent.haml:6:in `render'",
      "/vendor/mayu/hello.rb:123:in `update'",
    ])

    puts source_map.format_exception(e, "/app/components/MyComponent.haml")
  end
end
