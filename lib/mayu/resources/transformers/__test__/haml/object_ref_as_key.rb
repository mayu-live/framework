# frozen_string_literal: true
Self = setup_component(assets: [], styles: {})
public def render
  Mayu::VDOM::H[:div, **mayu.merge_props({ key: ["hello"] })]
end
