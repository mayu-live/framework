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

        sig { params(vnode: VNode).void }
        def enqueue_update!(vnode)
        end
      end

      module Descriptor
        extend T::Sig
        extend T::Helpers
        abstract!

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

        sig { abstract.params(other: Descriptor).returns(T::Boolean) }
        def same?(other)
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
      end
    end
  end
end
