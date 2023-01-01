# frozen_string_literal: true
Self = setup_component(assets: [], styles: {})
public def render
  return Mayu::VDOM.h(:div, **mayu.merge_props({ class: :foo })) if props[:foo]
  Mayu::VDOM.h(:div, **mayu.merge_props({ class: :bar }))
end
