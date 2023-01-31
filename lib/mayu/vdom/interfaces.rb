# typed: strict

module Mayu
  module VDOM
    module Interfaces
      module VTree
        extend T::Sig
        extend T::Helpers
        abstract!

        sig { abstract.returns(String) }
        def next_id!
        end

        sig { abstract.returns(Session) }
        def session
        end

        sig { abstract.params(path: String).void }
        def navigate(path)
        end

        sig { abstract.params(type: Symbol, payload: T.untyped).void }
        def action(type, payload)
        end

        sig { overridable.params(vnode: T.untyped).void }
        def enqueue_update!(vnode)
        end
      end

      module VNode
        extend T::Sig
        extend T::Helpers
        abstract!

        sig { abstract.returns(String) }
        def id
        end

        sig { abstract.returns(Descriptor) }
        def descriptor
        end
      end

      module Descriptor
        module Factory
          extend T::Sig
          extend T::Helpers
          abstract!

          sig { abstract.params(obj: T.untyped).returns(Descriptor) }
          def or_text(obj)
          end

          sig { abstract.params(text_content: T.untyped).returns(Descriptor) }
          def text(text_content)
          end

          sig { abstract.returns(Descriptor) }
          def comment
          end

          sig do
            abstract
              .params(children: Component::Children, parent_type: T.untyped)
              .returns(T::Array[Descriptor])
          end
          def clean(children, parent_type: nil)
          end

          sig do
            abstract
              .params(descriptors: T::Array[Descriptor])
              .returns(T::Array[Descriptor])
          end
          def add_comments_between_texts(descriptors)
          end
        end

        extend T::Sig
        extend T::Helpers
        abstract!

        TEXT = :TEXT
        COMMENT = :COMMENT

        sig { overridable.returns(T::Boolean) }
        def text? = type == TEXT

        sig { overridable.returns(T::Boolean) }
        def comment? = type == COMMENT

        sig { overridable.returns(T::Boolean) }
        def element? = type.is_a?(Symbol)

        sig { abstract.returns(T::Boolean) }
        def component?
        end

        sig { abstract.returns(Component::ElementType) }
        def type
        end

        sig { abstract.returns(Component::Props) }
        def props
        end

        sig { abstract.returns(T.untyped) }
        def key
        end

        sig { abstract.returns(String) }
        def slot
        end

        sig { overridable.returns(Children[Descriptor]) }
        def children = props[:children]

        sig { overridable.returns(T::Boolean) }
        def has_children? = children.any?

        sig { overridable.returns(String) }
        def text = props[:text_content].to_s

        sig { abstract.returns(T.class_of(Component::Base)) }
        def component_class
        end

        sig { returns(Descriptor) }
        def itself = self

        sig do
          type_parameters(:R)
            .params(
              block:
                T.proc.params(arg0: Descriptor).returns(T.type_parameter(:R))
            )
            .returns(T.type_parameter(:R))
        end
        def then(&block) = yield self

        ##
        # This is used for hash comparisons,
        # https://ruby-doc.org/3.2.0/Hash.html#class-Hash-label-User-Defined+Hash+Keys
        sig { overridable.returns(Integer) }
        def hash
          [type, slot, key, type == :input && props[:type]].hash
        end

        ##
        # This is used for hash comparisons,
        # https://ruby-doc.org/3.2.0/Hash.html#class-Hash-label-User-Defined+Hash+Keys
        sig { abstract.params(other: T.untyped).returns(T::Boolean) }
        def eql?(other)
        end

        sig do
          abstract.params(other: Interfaces::Descriptor).returns(T::Boolean)
        end
        def same?(other)
        end
      end

      module Children
        extend T::Sig
        extend T::Helpers
        extend T::Generic
        include Enumerable
        Elem = type_member { { upper: Descriptor } }
        abstract!

        sig do
          abstract
            .params(
              name: T.nilable(String),
              fallback: T.nilable(T.proc.returns(Descriptor))
            )
            .returns(T.nilable(T.any(Descriptor, T::Array[Descriptor])))
        end
        def slot(name = nil, &fallback)
        end
      end
    end
  end
end
