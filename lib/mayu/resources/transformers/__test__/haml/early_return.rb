# frozen_string_literal: true
Self = setup_component(assets: [], styles: {})
public def render
  begin
    return Mayu::VDOM.h(:div, **mayu.merge_props({ class: :foo })) if true
    nil
  end
  Mayu::VDOM.h(:div, **mayu.merge_props({ class: :bar }))
end
