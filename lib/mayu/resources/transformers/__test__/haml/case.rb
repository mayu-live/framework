# frozen_string_literal: true
Self = setup_component(assets: [], styles: {})
public def render
  Mayu::VDOM.h(
    :div,
    case props[:value]
    when "foo"
      Mayu::VDOM.h(:p, "Foo")
    when "bar"
      Mayu::VDOM.h(:p, "Bar")
    else
      Mayu::VDOM.h(:p, "Other")
    end
  )
end
