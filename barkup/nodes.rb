# typed: true

module Barkup
  class Node
    extend T::Sig
    extend T::Helpers
    abstract!

    sig { abstract.returns(String) }
    def to_s
    end
  end

  class Text < Node
    sig { params(content: String).void }
    def initialize(content)
      @content = content
    end

    sig { override.returns(String) }
    def to_s
      CGI.escape_html(@content)
    end
  end

  class Element < Node
    sig { params(node: T.untyped).returns(Node) }
    def self.or_text(node)
      node.is_a?(self) ? node : Text.new(node.to_s)
    end

    sig do
      params(
        type: Symbol,
        attrs: T::Hash[Symbol, T.untyped],
        children: T::Array[Node],
      ).void
    end
    def initialize(type, attrs, children)
      @type = type
      @attrs = attrs
      @children = children
    end

    sig { override.returns(String) }
    def to_s
      attrs =
        @attrs
          .map do |key, value|
            next value ? " #{key}" : nil if Mayu::HTML.boolean_attribute?(key)

            " #{CGI.escape_html(key.to_s)}=\"#{CGI.escape_html(value.to_s)}\""
          end
          .compact
          .join

      return "<#{@type}#{attrs}>" if Mayu::HTML.void_tag?(@type)

      "<#{@type}#{attrs}>#{@children.join}</#{@type}>"
    end
  end
end
