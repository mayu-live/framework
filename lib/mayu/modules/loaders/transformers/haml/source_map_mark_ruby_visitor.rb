# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

module Mayu
  module Modules
    module Loaders
      module Transformers
        module Haml
          class SourceMapMarkRubyVisitor < SyntaxTree::Visitor
            include SyntaxTree::DSL

            def initialize(source, offset)
              @source_lines = source.lines
              @offset = offset
            end

            def visit_program(node)
              return node
              node.copy(statements: visit(node.statements))
            end

            def visit_def(node)
              add_source_map_mark(node)
            end

            def visit_statements(node)
              node.body.each { add_source_map_mark(_1) }

              add_source_map_mark(node)
            end

            def visit_assign(node)
              add_source_map_mark(node)
            end

            private

            def add_source_map_mark(node)
              visit_child_nodes(node)

              code = @source_lines[node.location.start_line - 1].strip

              node.comments.replace(
                [
                  Modules::SourceMap::Mark[
                    @offset + node.location.start_line,
                    code
                  ].to_comment
                ]
              )

              node
            end
          end
        end
      end
    end
  end
end
