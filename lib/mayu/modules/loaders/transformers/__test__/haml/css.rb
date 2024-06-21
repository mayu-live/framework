# frozen_string_literal: true
class Css < Mayu::Component::Base
  def self.module_path
    __FILE__
  end
  Self = self
  FILENAME = __FILE__
  Styles =
    Mayu::StyleSheet[
      source_filename: "css.haml (inline css)",
      content_hash: "QRzl4L9HjW2wS-4CE_xH6vXN4WTNT72NL210gVqRO_c",
      classes: {
        button: "css.button?Trf1Txj1",
        "button-text": "css.button-text?Trf1Txj1"
      },
      content: <<CSS
.css\\.button\\?Trf1Txj1{color:#f0f}.css\\.button-text\\?Trf1Txj1{font-weight:700}
CSS
    ].merge(import?("css.css"))
  public def render
    H[
      :button,
      H[
        :span,
        "Click me",
        **self.class.merge_props({ class: :__span }, { class: :"button-text" })
      ],
      **self.class.merge_props({ class: :__button }, { class: :button })
    ]
  end
end
Default = Css
Default::Styles.each do
  add_asset(Mayu::Modules::Generators::Text[_1.filename, _1.content])
end
