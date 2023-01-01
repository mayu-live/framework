# frozen_string_literal: true
Self = setup_component(assets: [], styles: {})
public def render
  Mayu::VDOM.h(
    :div,
    Mayu::VDOM.h(
      :svg,
      Mayu::VDOM.h(:line, **mayu.merge_props({ stroke_width: 2 }))
    )
  )
end
