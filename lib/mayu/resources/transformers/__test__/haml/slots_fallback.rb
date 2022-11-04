public def render
  Mayu::VDOM.h(
    :div,
    Mayu::VDOM.slot(children) ||
      begin
        Mayu::VDOM.h(:p, "Fallback content")
      end
  )
end
