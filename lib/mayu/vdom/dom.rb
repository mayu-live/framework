# typed: strict

require "cgi"

module Mayu
  module VDOM
    class DOM
      extend T::Sig

      class DOMException < StandardError
      end

      class CSSStyleDeclaration
        extend T::Sig

        sig { void }
        def initialize
          @properties = T.let({}, T::Hash[String, String])
        end

        sig { params(name: String).returns(String) }
        def get_property_value(name)
          @properties[name].to_s
        end

        sig do
          params(name: String, value: T.any(String, Integer, Float)).returns(
            self
          )
        end
        def set_property(name, value)
          @properties[name] = value.to_s
          self
        end

        sig { params(name: String).returns(self) }
        def remove_property(name)
          @properties.delete(name)
          self
        end

        sig { returns(String) }
        def to_s
          @properties.map { "#{_1}: #{_2};" }.join(" ")
        end
      end

      class Node
        extend T::Sig

        sig { returns(Integer) }
        attr_reader :id

        sig { returns(T.nilable(Element)) }
        attr_reader :parent

        sig { returns(T.nilable(Node)) }
        def previous_sibling = parent&.find_previous_sibling(self)

        sig { returns(T.nilable(Node)) }
        def next_sibling = parent&.find_next_sibling(self)

        sig { params(document: DOM).void }
        def initialize(document)
          @document = T.let(document, DOM)
          @id = T.let(@document.next_id!, Integer)
          @parent = T.let(nil, T.nilable(Element))
        end

        sig { returns(T::Boolean) }
        def text? = false
        sig { returns(T::Boolean) }
        def element? = false

        sig { returns(String) }
        def to_s = ""

        sig do
          params(new_parent: T.nilable(Element)).returns(T.nilable(Element))
        end
        def parent=(new_parent)
          @parent&.remove_child(self)
          @parent = new_parent
        end

        sig { params(node: Node).returns(self) }
        def append_child(node)
          raise DOMException, "Can't append children to #{self.class.name}"
        end

        sig do
          params(new_node: Node, reference_node: T.nilable(Node)).returns(self)
        end
        def insert_before(new_node, reference_node = nil)
          raise DOMException, "Can't insert children to #{self.class.name}"
        end

        sig { params(node: Node).returns(self) }
        def remove_child(node)
          raise DOMException, "Can't remove children from #{self.class.name}"
        end
      end

      class Element < Node
        sig { returns(T::Array[Node]) }
        attr_reader :children

        sig { returns(CSSStyleDeclaration) }
        attr_reader :style

        sig { params(document: DOM, tag_name: Symbol).void }
        def initialize(document, tag_name)
          super(document)
          @tag_name = T.let(tag_name, Symbol)
          @children = T.let([], T::Array[Node])
          @attributes = T.let({}, T::Hash[String, String])
          @style = T.let(CSSStyleDeclaration.new, CSSStyleDeclaration)
        end

        sig { returns(T::Boolean) }
        def element? = true

        sig { returns(String) }
        def to_s
          attrs = [
            %{data-mayu-id="#{id}"},
            @attributes.map { %{#{_1}="#{CGI.escape(_2)}"} }
          ].flatten.join(" ")

          if children.empty?
            "<#{@tag_name} #{attrs} />"
          else
            "<#{@tag_name} #{attrs}>#{children.join}</#{@tag_name}>"
          end
        end

        sig { params(name: String).returns(T.nilable(String)) }
        def get_attribute(name)
          @attributes[name]
        end

        sig { params(name: String, value: String).void }
        def set_attribute(name, value)
          @attributes[name] = value
        end

        sig { params(name: String).void }
        def remove_attribute(name)
          @attributes.delete(name)
        end

        sig { params(node: Node).returns(self) }
        def append_child(node)
          node.parent = self
          @children.push(node)
          self
        end

        sig do
          params(new_node: Node, reference_node: T.nilable(Node)).returns(self)
        end
        def insert_before(new_node, reference_node = nil)
          new_node.parent = self
          index = @children.index(reference_node) || -1
          @children.insert(index, new_node)
          self
        end

        sig { params(node: Node).returns(self) }
        def remove_child(node)
          @children.delete(node)
          self
        end

        sig { params(node: Node).returns(T.nilable(Node)) }
        def find_previous_sibling(node)
          index = @children.index(node).to_i
          @children[index.pred] if index > 1
        end

        sig { params(node: Node).returns(T.nilable(Node)) }
        def find_next_sibling(node)
          index = @children.index(node).to_i
          @children[index.succ] if index
        end
      end

      class Text < Node
        sig { params(document: DOM, data: String).void }
        def initialize(document, data)
          super(document)
          @data = T.let(data, String)
        end

        sig { returns(T::Boolean) }
        def text? = true

        sig { returns(String) }
        def to_s = @data
      end

      class Comment < Node
        sig { params(document: DOM, data: String).void }
        def initialize(document, data)
          super(document)
          @data = T.let(data, String)
        end

        sig { returns(T::Boolean) }
        def comment? = true

        sig { returns(String) }
        def to_s = "<!-- mayu-id: #{id}. #{@data} -->"
      end

      sig { returns(Element) }
      attr_reader :root

      sig { void }
      def initialize
        @id_counter = T.let(0, Integer)
        @root = T.let(create_element(:html), Element)
      end

      sig { params(tag_name: Symbol).returns(Element) }
      def create_element(tag_name)
        Element.new(self, tag_name)
      end

      sig { params(data: String).returns(Text) }
      def create_text_node(data)
        Text.new(self, data)
      end

      sig { returns(Integer) }
      def next_id! = @id_counter += 1
    end
  end
end
