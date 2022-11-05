public def render
  case props[:value]
  when "foo"
    Mayu::VDOM.h(:p, "Foo")
  when "bar"
    Mayu::VDOM.h(:p, "Bar")
  else
    Mayu::VDOM.h(:p, "Other")
  end
end
