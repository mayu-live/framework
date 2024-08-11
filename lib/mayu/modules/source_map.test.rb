# frozen_string_literal: true
#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "minitest/autorun"

require_relative "source_map"

class Mayu::Modules::SourceMap::Test < Minitest::Test
  SourceMap = Mayu::Modules::SourceMap

  def test_parse
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

    assert_equal(3, source_map.find_original_line_no(5))
    assert_equal(6, source_map.find_original_line_no(11))
  end
end
