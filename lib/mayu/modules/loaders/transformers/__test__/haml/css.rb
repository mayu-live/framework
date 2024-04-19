# frozen_string_literal: true
class Css < Mayu::Component::Base
  def self.module_path
    __FILE__
  end
  Self = self
  FILENAME = __FILE__
  Styles =
    Mayu::StyleSheet[
      source_filename:
        "/Users/andreas/Projects/mayu-live/framework/lib/mayu/modules/loaders/transformers/__test__/haml/css.haml (inline css)",
      content_hash: "5HZABHNkuR2dxz9RlgC0DfKE8pZseYPLg7US5JUy22s",
      classes: {
        button:
          "/Users/andreas/Projects/mayu-live/framework/lib/mayu/modules/loaders/transformers/__test__/haml/css.button?Trf1Txj1",
        "button-text":
          "/Users/andreas/Projects/mayu-live/framework/lib/mayu/modules/loaders/transformers/__test__/haml/css.button-text?Trf1Txj1"
      },
      content: <<CSS
.\\/Users\\/andreas\\/Projects\\/mayu-live\\/framework\\/lib\\/mayu\\/modules\\/loaders\\/transformers\\/__test__\\/haml\\/css\\.button\\?Trf1Txj1{color:#f0f}.\\/Users\\/andreas\\/Projects\\/mayu-live\\/framework\\/lib\\/mayu\\/modules\\/loaders\\/transformers\\/__test__\\/haml\\/css\\.button-text\\?Trf1Txj1{font-weight:700}
CSS
    ].merge(
      import?(
        "/Users/andreas/Projects/mayu-live/framework/lib/mayu/modules/loaders/transformers/__test__/haml/css.css"
      )
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
Default::Styles.each { add_asset(Assets::Asset.build(_1.filename, _1.content)) }
