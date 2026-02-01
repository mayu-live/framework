# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

require_relative "../mutation_visitor"

module Mayu
  module Modules
    module Loaders
      module Transformers
        module Haml
          class TransformSingleExpressionMethodsVisitor
            include SyntaxTree::DSL

            def visitor
              # Input:
              #   def foo = 123
              # Output:
              #   def foo
              #     123
              #   end
              # This makes source map comments show up on correct lines
              MutationVisitor.build do |visitor|
                visitor.mutate("DefNode[bodystmt: Statements]") do |node|
                  node.copy(
                    bodystmt: BodyStmt(node.bodystmt, nil, nil, nil, nil)
                  )
                end
              end
            end
          end
        end
      end
    end
  end
end
