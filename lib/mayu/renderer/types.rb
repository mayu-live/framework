# typed: strict

module Mayu
  module Renderer
    module Types
      ComponentChild = T.type_alias {
        T.nilable(
          T.any(
            VNode[T.untyped],
            String,
            Numeric,
            T::Boolean,
          )
        )
      }

      Props = T.type_alias { T::Hash[String, T.untyped] }
      State = T.type_alias { T::Hash[String, T.untyped] }
      Context = T.type_alias { T::Hash[String, T.untyped] }
    end
  end
end
