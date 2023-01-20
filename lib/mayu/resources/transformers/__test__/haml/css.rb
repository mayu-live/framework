# frozen_string_literal: true
Self =
  setup_component(
    assets: ["MhX21ANfU9yaX-4TrDS09Q78ezWwvMXHPC5iPRFjtwQ=.css"],
    styles: {
      button: "app/components/MyComponent.button?761847c0"
    }
  )
public def render
  Mayu::VDOM::H[:button, "Click me", **mayu.merge_props({ class: :button })]
end
