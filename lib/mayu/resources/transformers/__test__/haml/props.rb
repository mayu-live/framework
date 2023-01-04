# frozen_string_literal: true
Self = setup_component(assets: [], styles: {})
public def render
  Mayu::VDOM::H[
    :div,
    Mayu::VDOM::H[:h1, self.props[:title]],
    Mayu::VDOM::H[:h1, "hej #{self.props[:title][123]} asd"],
    Mayu::VDOM::H[:h2, $~],
    **mayu.merge_props({ class: self.props[:class] })
  ]
end
