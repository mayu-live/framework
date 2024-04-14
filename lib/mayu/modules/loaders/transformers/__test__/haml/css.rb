# frozen_string_literal: true
class Test < Mayu::Component::Base
  def self.module_path
    __FILE__
  end
  Self = self
  FILENAME = __FILE__
  Styles =
    Mayu::StyleSheet[
      source_filename: "/app/components/Test.haml (inline css)",
      content_hash: "II_m4Tqejb8BcNpaXciICXJBLLft4dvCnYoTLEm_hcc",
      classes: {
        button: "/app/components/Test.button?Trf1Txj1",
        "button-text": "/app/components/Test.button-text?Trf1Txj1"
      },
      content: <<CSS
.\\/app\\/components\\/Test\\.button\\?Trf1Txj1{color:#f0f}.\\/app\\/components\\/Test\\.button-text\\?Trf1Txj1{font-weight:700}
CSS
    ].merge(import?("/app/components/Test.css"))
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
Default = Test
Default::Styles.each { add_asset(Assets::Asset.build(_1.filename, _1.content)) }
