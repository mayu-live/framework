# frozen_string_literal: true
Self = setup_component(assets: [], styles: {})
public def render
  Mayu::VDOM.h(
    :p,
    "Blabla #{asd}",
    " ",
    Mayu::VDOM.h(:a, "hopp", **mayu.merge_props({ href: "asd" }))
  )
end
