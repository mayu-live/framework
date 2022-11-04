lol = "lol"
id = "check123"
props = { label: "label", asd: "asd" }

public def render
  Mayu::VDOM.h(
    :div,
    "hello",
    Mayu::VDOM.h(
      :input,
      **{ id: id },
      **{
        type: "checkbox",
        placeholder: props[:label],
        **props.except(:label)
      },
      class: styles[classname]
    ),
    **{ asdd: lol },
    class: styles[:foo, :bar, "baz"]
  )
end
