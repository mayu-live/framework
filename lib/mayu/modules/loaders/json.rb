# frozen_string_literal: true
#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require "json"
require_relative "transformers/frozen_string_literal_visitor"

module Mayu
  module Modules
    module Loaders
      JSON =
        Data.define do
          include SyntaxTree::DSL

          def call(loading_file)
            loading_file.maybe_load_source.transform do |loading_file|
              SyntaxTree::Formatter.format("", build_code(loading_file.source))
              # .tap { |source| puts source }
            end
          end

          private

          def build_code(source)
            ::JSON
              .parse(source)
              .inspect
              .then { SyntaxTree.parse(_1) }
              .statements
              .body => [content_ast]

            Statements(
              [Assign(VarField(Const("Default")), deep_freeze(content_ast))]
            ).accept(Transformers::FrozenStringLiteralVisitor.new)
          end

          def deep_freeze(ast)
            CallNode(
              ConstPathRef(
                ConstPathRef(VarRef(Const("Mayu")), Const("Utils")),
                Const("DeepFreeze")
              ),
              Period("."),
              Ident("deep_freeze"),
              ArgParen(Args([ast]))
            )
          end
        end
    end
  end
end
