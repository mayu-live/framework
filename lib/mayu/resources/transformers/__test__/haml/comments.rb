# frozen_string_literal: true
Self = setup_component(assets: [], styles: {})
public def render
  Mayu::VDOM.h(:div, Mayu::VDOM.h(:foo), Mayu::VDOM.h(:bar))
end
