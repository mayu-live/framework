# frozen_string_literal: true
Self = setup_component(assets: [], styles: {})
public def render
  Mayu::VDOM.h(
    :div,
    Mayu::VDOM.h(:div, "foo #{bar} baz"),
    Mayu::VDOM.h(:div, "foo #{bar} baz"),
    Mayu::VDOM.h(:div, "foo #{bar} baz"),
    Mayu::VDOM.h(:div, ("lol #{boll} polle" if bar))
  )
end
