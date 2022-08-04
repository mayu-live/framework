# typed: strict

extend T::Sig

GlobalProps = T.type_alias { { tabindex: Numeric } }

UlProps = T.type_alias { { foo: String, bar: Numeric } }

sig { params(children: String, foo: T.nilable(String), props: T.untyped).void }
def ul(*children, foo: nil, **props)
  p [children, props]
end

ul("123", "hopp", foo: "asd")
