# frozen_string_literal: true
Self = setup_component(assets: [], styles: {})
begin
  lol = "lol"
  id = "check123"
  props = { label: "label", asd: "asd" }
end
public def render
  Mayu::VDOM.h(
    :div,
    "hello",
    Mayu::VDOM.h(
      :input,
      **mayu.merge_props(
        {
          class: classname,
          type: "checkbox",
          placeholder: props[:label],
          **props.except(:label)
        },
        { id: id }
      )
    ),
    **mayu.merge_props({ class: %i[foo bar] }, { class: "baz" }, { asdd: lol })
  )
end
