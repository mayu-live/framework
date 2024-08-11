# frozen_string_literal: true
class Css < Mayu::Component::Base
  def self.module_path
    __FILE__
  end
  Self = self
  INLINE_STYLES = [
    begin
      Mayu::StyleSheet[
        source_filename: "css.haml.css",
        content_hash: "EBs7RoAYfBSDj2sC3blS79YHXlExe5hl3x_N9IfwMt0",
        classes: {
          button: "css.haml.button?Trf1Txj1",
          "button-text": "css.haml.button-text?Trf1Txj1"
        },
        content: <<CSS
.css\\.haml\\.button\\?Trf1Txj1{color:#f0f}.css\\.haml\\.button-text\\?Trf1Txj1{font-weight:700}
CSS
      ]
    end
  ]
  Styles =
    Mayu::Component::StyleSheets.new(
      self,
      [*INLINE_STYLES, import?("./css.css")].compact
    )
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
Default::INLINE_STYLES.each do
  add_asset(Mayu::Assets::Generators::Text[_1.filename, _1.content])
end
