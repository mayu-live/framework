# frozen_string_literal: true
Self = setup_component(assets: [], styles: {})
public def render
  Mayu::VDOM.h(:div, mayu.slot { Mayu::VDOM.h(:p, "Fallback content") })
end
