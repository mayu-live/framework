public def render
  Mayu::VDOM.h(
    :div,
    Mayu::VDOM.h(:p, "Hello World"),
    Mayu::VDOM.h(:p, "Hello World"),
    Mayu::VDOM.h(:p, "Hello World"),
    Mayu::VDOM.h(:p, "Hello World")
  )
end
