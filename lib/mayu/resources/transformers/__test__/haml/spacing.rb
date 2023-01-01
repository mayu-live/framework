# frozen_string_literal: true
Self = setup_component(assets: [], styles: {})
public def render
  Mayu::VDOM.h(
    :p,
    "There should be no space on the left of this text. But there should be one between this line and the previous line. ",
    Mayu::VDOM.h(
      :a,
      "And there should be spaces before this link",
      **mayu.merge_props({ href: "/" })
    ),
    ". Was there?"
  )
end
