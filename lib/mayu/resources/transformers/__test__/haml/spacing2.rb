# frozen_string_literal: true
Self = setup_component(assets: [], styles: {})
public def render
  Mayu::VDOM::H[
    :div,
    Mayu::VDOM::H[:p, "Hello World"],
    Mayu::VDOM::H[:p, "Hello World"],
    Mayu::VDOM::H[:p, "Hello World"],
    Mayu::VDOM::H[:p, "Hello World"]
  ]
end
