# frozen_string_literal: true
#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

module Mayu
  module Modules
    module Loaders
      module Transformers
        class FrozenStringLiteralVisitor < SyntaxTree::Visitor
          def visit_program(node)
            node.copy(statements: visit(node.statements))
          end

          def visit_statements(node)
            node.copy(
              body: [
                SyntaxTree::Comment.new(
                  value: "# frozen_string_literal: true",
                  inline: false,
                  location: node.location
                ),
                *node.body
              ]
            )
          end
        end
      end
    end
  end
end
