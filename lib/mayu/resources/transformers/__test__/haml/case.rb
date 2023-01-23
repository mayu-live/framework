# frozen_string_literal: true
Self = setup_component(assets: [], styles: {})
public def render
  Mayu::VDOM::H[
    :div,
    case props[:value]
    when "foo"
      Mayu::VDOM::H[:p, "Foo"]
    when "bar"
      Mayu::VDOM::H[:p, "Bar"]
    else
      Mayu::VDOM::H[:p, "Other"]
    end
  ]
end
