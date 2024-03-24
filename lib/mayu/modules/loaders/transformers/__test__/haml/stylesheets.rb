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
      content_hash: "F2Z4_LlGkoj31SdZSm7XcwoREsDkQyK8wl9TKOG_8xE",
      classes: {
        __h1: "/app/components/Test_h1?ct99ezRm",
        world: "/app/components/Test.world?ct99ezRm"
      },
      content: <<CSS
.\\/app\\/components\\/Test_h1\\?ct99ezRm{color:#f0f}.\\/app\\/components\\/Test\\.world\\?ct99ezRm{background:#f0f}
CSS
    ].merge(import?("/app/components/Test.css"))
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
Default = Test
Default::Styles.each { add_asset(Assets::Asset.build(_1.filename, _1.content)) }
