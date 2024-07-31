# frozen_string_literal: true
class Stylesheets < Mayu::Component::Base
  def self.module_path
    __FILE__
  end
  Self = self
  FILENAME = __FILE__
  Styles =
    Mayu::Component::StyleSheets.new(
      self,
      [
        Mayu::StyleSheet[
          source_filename: "stylesheets.haml (inline css)",
          content_hash: "R6kIl4_IwYp2R6BekTTwSY18oRRIDM1BaHtBsFX5Zag",
          classes: {
            __h1: "stylesheets_h1?ct99ezRm",
            world: "stylesheets.world?ct99ezRm"
          },
          content: <<CSS
.stylesheets_h1\\?ct99ezRm{color:#f0f}.stylesheets\\.world\\?ct99ezRm{background:#f0f}
CSS
        ],
        import?("./stylesheets.css")
      ].compact
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
Default::Styles.each do
  add_asset(Mayu::Assets::Generators::Text[_1.filename, _1.content])
end
