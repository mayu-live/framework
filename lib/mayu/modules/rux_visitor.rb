# typed: struct

require "cgi"
require "rux"

module Mayu
  module Modules
    class RuxVisitor < Rux::Visitor
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
        "".tap do |result|
          block_arg =
            if (as = node.attrs["as"])
              visit(as)
            end

          at =
            node
              .attrs
              .each_with_object([]) do |(k, v), ret|
                next if k == "as"
                ret << Rux::Utils.attr_to_hash_elem(k, visit(v))
              end

          if node.name.start_with?(/[A-Z]/)
            result << "Mayu::VDOM.h(#{node.name}"
          else
            result << "Mayu::VDOM.h(#{node.name.to_sym.inspect}"
          end

          #unless node.attrs.empty?
          result << ", { #{at.join(", ")} }"
          #end

          children =
            node.children.reject do |child|
              child.is_a?(Rux::AST::TextNode) && child.text.match(/\A\s*\Z/)
            end

          if children.size > 0
            result << ", ["
            result << children.map { visit(_1).strip }.join(", ")
            result << "]"
          end

          result << ")"
        end
      end

      def visit_text(node)
        CGI.escape_html(node.text).inspect
      end
    end
  end
end
