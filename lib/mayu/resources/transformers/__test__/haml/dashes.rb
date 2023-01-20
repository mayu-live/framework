# frozen_string_literal: true
Self = setup_component(assets: [], styles: {})
public def render
  Mayu::VDOM::H[
    :div,
    Mayu::VDOM::H[
      :svg,
      Mayu::VDOM::H[:line, **mayu.merge_props({ stroke_width: 2 })]
    ]
  ]
end
