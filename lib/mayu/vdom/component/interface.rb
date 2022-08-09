# typed: strict

require_relative "../component"

module Mayu
  module VDOM
    module Component
      module Interface
        extend T::Sig
        extend T::Helpers
        interface!

        sig { abstract.params(props: Props, state: State).returns(T::Boolean) }
        def should_update?(props, state)
        end

        sig { abstract.returns(T.any(T.nilable(Descriptor), [Descriptor])) }
        def render
        end

        sig { abstract.void }
        def mount
        end
        sig { abstract.void }
        def unmount
        end

        sig { abstract.params(prev_props: Props, prev_state: State).void }
        def did_update(prev_props, prev_state)
        end
      end
    end
  end
end
