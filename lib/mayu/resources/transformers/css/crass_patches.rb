# typed: false
require "crass"

# This patch parses @media and @layer as style rules.

module Crass
  class Parser
    def consume_at_rule(input = @tokens)
      rule = {}

      rule[:tokens] = input.collect do
        rule[:name] = input.consume[:value]
        rule[:prelude] = []

        while token = input.consume
          node = token[:node]

          if node == :comment
            # Non-standard.
            next
          elsif node == :semicolon
            break
          elsif node === :"{"
            case rule[:name]
            in "media" | "layer"
              rule[:block] = consume_list_of_declarations(input)
            else
              # Note: The spec says the block should _be_ the consumed simple
              # block, but Simon Sapin's CSS parsing tests and tinycss2 expect
              # only the _value_ of the consumed simple block here. I assume I'm
              # interpreting the spec too literally, so I'm going with the
              # tinycss2 behavior.
              rule[:block] = consume_simple_block(input)[:value]
            end
            break
          elsif node == :simple_block && token[:start] == "{"
            # Note: The spec says the block should _be_ the simple block, but
            # Simon Sapin's CSS parsing tests and tinycss2 expect only the
            # _value_ of the simple block here. I assume I'm interpreting the
            # spec too literally, so I'm going with the tinycss2 behavior.
            rule[:block] = token[:value]
            break
          else
            input.reconsume
            rule[:prelude] << consume_component_value(input)
          end
        end
      end

      create_node(:at_rule, rule)
    end

    def consume_list_of_declarations(input = @tokens)
      rules = []

      while token = input.consume
        if token[:node] == :"}"
          puts "BREAKING"
          break
        end

        if token[:node] == :whitespace
          rules << token unless rules.empty?
          next
        end

        @tokens.reconsume

        if rule = consume_qualified_rule
          if rule[:node] == :qualified_rule
            rules << create_style_rule(rule)
          else
            rules << rule
          end
        end
      end

      rules
    end
  end
end
