# frozen_string_literal: true
Self = setup_component(assets: [], styles: {})
public def render
  Mayu::VDOM::H[:div, Mayu::VDOM::H[:foo], Mayu::VDOM::H[:bar]]
end
