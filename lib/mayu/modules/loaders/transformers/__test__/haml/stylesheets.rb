# frozen_string_literal: true
class Stylesheets < Mayu::Component::Base
  def self.module_path
    __FILE__
  end
  Self = self
  FILENAME = __FILE__
  Styles =
    Mayu::StyleSheet[
      source_filename:
        "/Users/andreas/Projects/mayu-live/framework/lib/mayu/modules/loaders/transformers/__test__/haml/stylesheets.haml (inline css)",
      content_hash: "5o5zqFp_qnESy2JDHouwZVMDiR6WbWehIOmbQ0XCqv0",
      classes: {
        __h1:
          "/Users/andreas/Projects/mayu-live/framework/lib/mayu/modules/loaders/transformers/__test__/haml/stylesheets_h1?ct99ezRm",
        world:
          "/Users/andreas/Projects/mayu-live/framework/lib/mayu/modules/loaders/transformers/__test__/haml/stylesheets.world?ct99ezRm"
      },
      content: <<CSS
.\\/Users\\/andreas\\/Projects\\/mayu-live\\/framework\\/lib\\/mayu\\/modules\\/loaders\\/transformers\\/__test__\\/haml\\/stylesheets_h1\\?ct99ezRm{color:#f0f}.\\/Users\\/andreas\\/Projects\\/mayu-live\\/framework\\/lib\\/mayu\\/modules\\/loaders\\/transformers\\/__test__\\/haml\\/stylesheets\\.world\\?ct99ezRm{background:#f0f}
CSS
    ].merge(
      import?(
        "/Users/andreas/Projects/mayu-live/framework/lib/mayu/modules/loaders/transformers/__test__/haml/stylesheets.css"
      )
    )
  public def render
    H[
      :div,
      H[:h1, "Hello", **self.class.merge_props({ class: :__h1 })],
      H[
        :p,
        "world",
        **self.class.merge_props({ class: :__p }, { class: :world })
      ],
      **self.class.merge_props({ class: :__div })
    ]
  end
end
Default = Stylesheets
Default::Styles.each { add_asset(Assets::Asset.build(_1.filename, _1.content)) }
