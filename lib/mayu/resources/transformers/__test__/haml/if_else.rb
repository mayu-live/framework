# frozen_string_literal: true
Self = setup_component(assets: [], styles: {})
begin
  # setup
end
public def render
  if true
    Mayu::VDOM::H[:div, **mayu.merge_props({ class: :foo })]
  else
    Mayu::VDOM::H[:div, **mayu.merge_props({ class: :bar })]
  end
end
