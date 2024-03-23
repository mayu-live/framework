# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# Released under AGPL-3.0

require "strscan"

module VDOM
  class XMLUtils
    Token =
      Data.define(:type, :value) do
        def to_s = inspect

        def inspect
          case self
          in { type: :tag, value: { name:, attrs:, children: } }
            str = [name.to_sym, *children, *attrs].map(&:inspect)
              .reject(&:empty?)
              .join(", ")
            "h(#{str})"
          in { type: :attr, value: { name:, value: } }
            " #{name}: #{value.inspect}"
          in { type: :var_ref, value: /\A@(.*)/ }
            "self.state[:#{$~[1]}]"
          in { type: :var_ref, value: /\A\$(.*)/ }
            "self.props[:#{$~[1]}]"
          in type: :newline
            ""
          in { type: :string, value: }
            value.inspect
          in { type: :statements, value: }
            SyntaxTree::Formatter.format("", value)
          in { type:, value: }
            "[#{type} #{value.inspect}]"
          end
        end
      end

    class Tokenizer
      def T(type, value = nil)
        @tokens.push(Token[type, value])
      end

      def initialize
        @tokens = []
        @state = :any
      end

      attr_reader :tokens

      def tokenize(source)
        ss = StringScanner.new(source.lstrip)

        until ss.eos?
          new_state =
            case p(@state)
            in :any
              tokenize_any(ss)
            in :string
              tokenize_string(ss)
            in :tag
              tokenize_tag(ss)
            in :attrs
              tokenize_attrs(ss)
            in :attr_value
              tokenize_attr_value(ss)
            end
          @state = new_state
        end
      end

      private

      def tokenize_any(ss)
        case
        when ss.scan(/</)
          :tag
        when ss.scan(/\n/)
          T(:newline)
          :any
        else
          :string
        end
      end

      def tokenize_string(ss)
        parts = []

        while str = ss.scan_until(/</m)
          if str[-2] == "\\"
            parts.push(str)
          else
            parts.push(str.delete_suffix("<"))
            T(:string, parts.join)
            return :tag
          end
        end

        if str = ss.scan_until(/\z/m)
          parts.push(str)
          T(:string, parts.join)
          return :any
        end

        raise
      end

      def tokenize_tag(ss)
        is_end_tag = !!ss.scan("/")
        tag_name = ss.scan(/\w+/)

        unless tag_name
          raise "Expected tag name at #{ss.pos} #{ss.peek(5).inspect}"
        end

        if is_end_tag
          ss.scan(/>/) or raise "Expected tag to end!"
          T(:close_tag, tag_name)
          return :any
        end

        T(:open_tag_begin, tag_name)

        :attrs
      end

      def tokenize_attrs(ss)
        ss.skip(/\s+/)

        if ss.scan(/>/)
          T(:open_tag_end)
          return :any
        end

        if ss.scan(%r{/})
          raise "Expected > after /" unless ss.scan(/>/)

          T(:open_tag_end, self_closing: true)

          return :any
        end

        attr = ss.scan(/\w+/)

        return :attrs unless attr

        T(:attr_name, attr)

        if ss.scan(/=/)
          T(:attr_assign)
          :attr_value
        else
          :attrs
        end
      end

      def tokenize_attr_value(ss)
        if var_ref = ss.scan(/[@$][\w_]+/)
          T(:var_ref, var_ref)
          return :attrs
        end

        if value_begin = ss.scan(/"/)
          if value = ss.scan_until(/"/)[0...-1]
            T(:attr_value, value)
            return :attrs
          end
        end

        raise "Expected value at #{ss.pos}"
      end
    end

    class Parser
      def initialize
        @tokens = []
      end

      attr_reader :tokens

      def parse(tokens)
        @tokens.push(parse_any(tokens)) until tokens.empty?

        self
      end

      private

      def parse_any(tokens, close_tag = nil)
        case p(token = tokens.shift)
        in { type: :open_tag_begin, value: }
          parse_tag(tokens, value)
        in type: :string
          token
        in type: :newline
          token
        in type: :close_tag
          token
        in type: :statements
          token
        in nil
          raise "Unexpected end of tokens"
        end
      end

      def parse_tag(tokens, name)
        attrs = []

        while token = tokens.shift
          case token
          in { type: :open_tag_end, value: { self_closing: true } }
            return Token[:tag, { name:, attrs:, children: [] }]
          in type: :open_tag_end
            children = parse_children(tokens, name)
            return Token[:tag, { name:, attrs:, children: }]
          in { type: :attr_name, value: }
            attrs.push(parse_attr(tokens, value))
          end
        end
      end

      def parse_children(tokens, close_tag)
        children = []

        while token = parse_any(tokens, close_tag)
          case token
          in { type: :close_tag, value: close_tag }
            return children
          in { type: :close_tag, value: }
            raise "Expected close tag for #{close_tag} but got #{value}"
          else
            children.push(token)
          end
        end

        children
      end

      def parse_attr(tokens, name)
        while token = tokens.shift
          case token
          in type: :attr_assign
            next
          in type: :var_ref
            return Token[:attr, { name:, value: token }]
          in type: :attr_value
            return Token[:attr, { name:, value: token }]
          end
        end
      end
    end
  end
end

if __FILE__ == $0
  tokenizer = VDOM::XMLUtils::Tokenizer.new

  tokenizer.tokenize(<<~HTML)
    <div class=@class>
      <p>asd: asdasd</p>
  HTML

  puts "Before:"
  puts tokenizer.tokens

  index = tokenizer.tokens.length

  tokenizer.tokenize(<<~HTML)
    </div>
  HTML

  puts "Added:"
  puts tokenizer.tokens.slice(index..-1)

  parser = VDOM::XMLUtils::Parser.new

  puts "Parsed"
  puts parser.parse(tokenizer.tokens.dup).tokens
end
