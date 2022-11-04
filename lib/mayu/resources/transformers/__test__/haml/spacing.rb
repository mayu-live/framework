public def render
  Mayu::VDOM.h(
    :p,
    "There should be no space on the left of this text. But there should be one between this line and the previous line.",
    " ",
    Mayu::VDOM.h(:a, "And there should be spaces before this link", href: "/"),
    ". Was there?"
  )
end
