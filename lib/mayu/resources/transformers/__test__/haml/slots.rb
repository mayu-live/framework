public def render
  Mayu::VDOM.h(
    :body,
    Mayu::VDOM.h(:main, Mayu::VDOM.slot(children)),
    Mayu::VDOM.h(:footer, Mayu::VDOM.slot(children, "footer"))
  )
end
