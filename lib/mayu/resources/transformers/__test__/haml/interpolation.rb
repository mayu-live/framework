# frozen_string_literal: true
Self = setup_component(assets: [], styles: {})
public def render
  Mayu::VDOM::H[
    :div,
    Mayu::VDOM::H[:div, "foo #{bar} baz"],
    Mayu::VDOM::H[:div, "foo #{bar} baz"],
    Mayu::VDOM::H[:div, "foo #{bar} baz"],
    Mayu::VDOM::H[:div, ("lol #{boll} polle" if bar)]
  ]
end
