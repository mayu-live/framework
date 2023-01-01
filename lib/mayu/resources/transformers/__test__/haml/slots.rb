# frozen_string_literal: true
Self = setup_component(assets: [], styles: {})
public def render
  Mayu::VDOM.h(
    :body,
    Mayu::VDOM.h(:main, mayu.slot),
    Mayu::VDOM.h(:footer, mayu.slot("footer"))
  )
end
