# frozen_string_literal: true
Self =
  setup_component(
    assets: ["Cd9Qx4lhkbeZyruovAokW1FL3tHSmMOxOc-2y1h7Zvc=.css"],
    styles: {
      button: "app/components/MyComponent.button?dhhHwAZl"
    }
  )
public def render
  Mayu::VDOM::H[:button, "Click me", **mayu.merge_props({ class: :button })]
end
