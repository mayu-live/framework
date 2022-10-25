# typed: true
# frozen_string_literal: true

require "rux"

class Rux::Parser
  # https://github.com/camertron/rux/pull/3
  def squeeze_lit(lit)
    lit
      .sub(/\A\s+/) { |s| s.match?(/[\r\n]/) ? "" : s }
      .sub(/\s+\z/) { |s| s.match?(/[\r\n]/) ? "" : s }
      .gsub(/\s+/, " ")
  end
end

module Mayu
  module Resources
    module Transformers
      module Rux
        extend T::Sig

        sig { params(source: String).returns(String) }
        def self.to_ruby(source)
          ::Rux.to_ruby(source, visitor: RuxVisitor.new)
        end

        class RuxVisitor < ::Rux::Visitor
          def visit_list(node)
            node.children.map { |child| visit(child) }.join
          end

          def visit_ruby(node)
            node.code
          end

          def visit_string(node)
            node.str
          end

          def visit_tag(node)
            "Mayu::VDOM.h2(%s)" %
              [
                visit_tag_name(node.name),
                *node.children.compact.map { visit(_1).strip },
                *node.attrs.map do |k, v|
                  ::Rux::Utils.attr_to_hash_elem(k, visit(v))
                end
              ].join(", ")
          end

          def visit_tag_name(name)
            name.start_with?(/[A-Z]/) ? name : name.to_sym.inspect
          end

          def visit_text(node)
            node.text.to_s.inspect
          end
        end
      end
    end
  end
end
