# frozen_string_literal: true
class Class_names < Mayu::Component::Base
  def self.module_path
    __FILE__
  end
  Self = self
  FILENAME = __FILE__
  Styles = Mayu::NullStyleSheet[self].merge(import?("class_names.css"))
  begin
    # SourceMapMark:2:bG9sID0gImxvbCI=
    lol = "lol"
    # SourceMapMark:3:aWQgPSAiY2hlY2sxMjMi
    id = "check123"
    # SourceMapMark:4:cHJvcHMgPSB7IGxhYmVsOiAibGFiZWwiLCBhc2Q6ICJhc2QiIH0=
    props = { label: "label", asd: "asd" }
    nil
  end
  public def render
    H[
      :div,
      # SourceMapMark:7:ImhlbGxvIg==
      "hello",
      H[
        :input,
        **self.class.merge_props(
          { class: :__input },
          # SourceMapMark:8:ewpjbGFzczogY2xhc3NuYW1lLAp0eXBlOiAiY2hlY2tib3giLApwbGFjZWhvbGRlcjogcHJvcHNbOmxhYmVsXSwKKipwcm9wcy5leGNlcHQoOmxhYmVsKSwKfQ==,
          {
            class: classname,
            type: "checkbox",
            placeholder: props[:label],
            **props.except(:label)
          },
          # SourceMapMark:8:eyJpZCIgPT4gaWQsfQ==,
          { id: id }
        )
      ],
      **self.class.merge_props(
        { class: :__div },
        { class: %i[foo bar] },
        # SourceMapMark:6:e2NsYXNzOiAiYmF6In0=,
        { class: "baz" },
        # SourceMapMark:6:eyJhc2RkIiA9PiBsb2wsfQ==,
        { asdd: lol }
      )
    ]
  end
end
Default = Class_names
Default::Styles.each do
  add_asset(Mayu::Modules::Generators::Text[_1.filename, _1.content])
end
