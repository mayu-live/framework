# typed: strict
# frozen_string_literal: true

module Mayu
  module Resources
    module Transformers
      module CSS
        class Formatter
          extend T::Sig

          sig { params(ast: T.untyped).returns(String) }
          def self.format_ast(ast)
            out = StringIO.new
            new(out).format(ast)
            out.rewind
            out.read.to_s
          end

          sig { params(out: StringIO).void }
          def initialize(out)
            @out = out
          end

          sig { params(token: T.untyped).void }
          def format(token)
            case token
            in Array
              token.each { format(_1) }
            in { node: :style_rule, selector:, children: }
              format(selector)
              @out << "{"
              format(children)
              @out << "}"
            in { node: :selector, tokens: }
              format(tokens)
            in { node: :whitespace, raw: }
              @out << raw
            in { node: :ident, value: }
              @out << value
            in { node: :semicolon, raw: }
              @out << raw
            in { node: :colon, raw: }
              @out << raw
            in { node: :comma, raw: }
              @out << raw
            in { node: :function, name:, value: }
              @out << "#{name}("
              format(value)
              @out << ")"
            in { node: :delim, raw: }
              @out << raw
            in { node: :string, raw: }
              @out << raw
            in { node: :simple_block, start:, end: end2, value: }
              @out << start
              format(value)
              @out << end2
            in { node: :property, name:, value: }
              @out << "#{name}: #{value}"
            in { node: :id, raw: }
              @out << raw
            in { node: :dimension, raw: }
              @out << raw
            in { node: :percentage, raw: }
              @out << raw
            in { node: :number, raw: }
              @out << raw
            in { node: :hash, raw: }
              @out << raw
            in { node: :error, value: }
              # TODO: Investigate why we get errors on valid code
            in { node: :at_rule, name:, prelude:, block: }
              @out << "@#{name}"
              format(prelude)
              @out << "{\n"
              format(block)
              @out << "}"
            end
          end
        end
      end
    end
  end
end
