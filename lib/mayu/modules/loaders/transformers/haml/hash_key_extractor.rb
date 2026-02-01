# frozen_string_literal: true

# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

module Mayu
  module Modules
    module Loaders
      module Transformers
        module Haml
          class HashKeyExtractorVisitor
            def visit_hash(node)
              hash = {}

              node.assocs.each do |child|
                if extract_key(child.key) in key
                  hash[key] = extract_value(child.value)
                end
              end

              hash
            end

            def extract_key(node)
              case node
              when SyntaxTree::StringLiteral
                node.parts => [{ value: }]
                value
              when SyntaxTree::Label
                node.value
              end
            end

            def extract_value(node)
              node
            end
          end
        end
      end
    end
  end
end
