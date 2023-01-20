# frozen_string_literal: true
Self = setup_component(assets: [], styles: {})
public def render
  Mayu::VDOM::H[
    :body,
    Mayu::VDOM::H[:main, mayu.slot],
    Mayu::VDOM::H[:footer, mayu.slot("footer")]
  ]
end
