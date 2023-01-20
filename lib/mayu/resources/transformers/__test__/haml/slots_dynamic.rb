# frozen_string_literal: true
Self = setup_component(assets: [], styles: {})
public def render
  begin
    name = "foo"
    nil
  end
  mayu.slot(name) { Mayu::VDOM::H[:p, "Fallback content"] }
end
