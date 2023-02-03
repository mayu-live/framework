# frozen_string_literal: true
Self =
  setup_component(
    assets: ["rKxGn-R511h2m1nlvs18PwsPwrzW-iGCNVojf-x0LRg=.css"],
    styles: {
      button: "app/components/MyComponent.button?dhhHwAZl"
    }
  )
public def render
  Mayu::VDOM::H[:button, "Click me", **mayu.merge_props({ class: :button })]
end
