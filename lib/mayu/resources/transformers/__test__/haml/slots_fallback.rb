# frozen_string_literal: true
Self = setup_component(assets: [], styles: {})
public def render
  Mayu::VDOM::H[:div, mayu.slot { Mayu::VDOM::H[:p, "Fallback content"] }]
end
