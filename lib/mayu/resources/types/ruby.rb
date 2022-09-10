# typed: strict

require "rux"
require_relative "base"

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
    module Types
      class Ruby < Base
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
            "Mayu::VDOM.h2(%s)" %
              [
                if node.name.start_with?(/[A-Z]/)
                  node.name
                else
                  node.name.to_sym.inspect
                end,
                *node.children.compact.map { visit(_1).strip },
                *node.attrs.map do |k, v|
                  Rux::Utils.attr_to_hash_elem(k, visit(v))
                end
              ].join(", ")
          end

          def visit_text(node)
            node.text.to_s.inspect
          end
        end

        sig { override.params(resource: Resource).returns(T.attached_class) }
        def self.load(resource)
          source = File.read(resource.absolute_path)

          if resource.absolute_path.end_with?(".rux")
            puts source
            source = Rux.to_ruby(source, visitor: RuxVisitor.new)
          end

          klass =
            T.let(
              T.cast(Class.new(Component::Base), T.class_of(Component::Base)),
              T.class_of(Component::Base)
            )

          klass.__mayu_resource = resource
          klass.class_eval(source, resource.path, 1)

          styles = resource.system.load_css(resource)

          klass.define_singleton_method(:stylesheet) { styles.type } if styles

          new(resource, klass)
        end

        sig { returns(T.class_of(Component::Base)) }
        attr_reader :klass

        sig do
          params(resource: Resource, klass: T.class_of(Component::Base)).void
        end
        def initialize(resource, klass)
          super(resource)
          @klass = klass
        end
      end
    end
  end
end
