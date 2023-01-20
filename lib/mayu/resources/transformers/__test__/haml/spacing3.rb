# frozen_string_literal: true
Self = setup_component(assets: [], styles: {})
public def render
  Mayu::VDOM::H[
    :p,
    "Blabla #{asd}",
    " ",
    Mayu::VDOM::H[:a, "hopp", **mayu.merge_props({ href: "asd" })]
  ]
end
