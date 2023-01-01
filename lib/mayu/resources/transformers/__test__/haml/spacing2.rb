# frozen_string_literal: true
Self = setup_component(assets: [], styles: {})
public def render
  Mayu::VDOM.h(
    :div,
    Mayu::VDOM.h(:p, "Hello World"),
    Mayu::VDOM.h(:p, "Hello World"),
    Mayu::VDOM.h(:p, "Hello World"),
    Mayu::VDOM.h(:p, "Hello World")
  )
end
