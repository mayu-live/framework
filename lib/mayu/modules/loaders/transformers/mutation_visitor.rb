require "syntax_tree"
require "syntax_tree/mutation_visitor"

module Mayu
  module Modules
    module Loaders
      module Transformers
        class MutationVisitor < SyntaxTree::MutationVisitor
          def self.build(&) = new.tap(&)

          def visit_assign(node)
            node.copy(target: visit(node.target), value: visit(node.value))
          end

          def visit_unary(node)
            node.copy(statement: visit(node.statement))
          end

          def visit_opassign(node)
            node.copy(target: visit(node.target), value: visit(node.value))
          end

          def visit_rassign(node)
            node.copy(
              operator: visit(node.operator),
              pattern: visit(node.pattern),
              value: visit(node.value)
            )
          end

          def visit_assoc_splat(node)
            node.copy(value: visit(node.value))
          end

          def visit_field(node)
            node.copy(
              parent: visit(node.parent),
              operator: node.operator == :"::" ? :"::" : visit(node.operator),
              name: visit(node.name)
            )
          end

          def visit_binary(node)
            node.copy(left: visit(node.left), right: visit(node.right))
          end

          def visit_lambda(node)
            node.copy(
              params: visit(node.params),
              statements: visit(node.statements)
            )
          end

          def visit_assoc(node)
            node.copy(key: visit(node.key), value: visit(node.value))
          end

          def visit_aref(node)
            node.copy(
              collection: visit(node.collection),
              index: visit(node.index)
            )
          end

          def visit_if_op(node)
            node.copy(
              predicate: visit(node.predicate),
              truthy: visit(node.truthy),
              falsy: visit(node.falsy)
            )
          end
        end
      end
    end
  end
end
