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
      content_hash: "FmoF815t3OvnBIkZL1_W0EjCkEOEvPsG1A3wNosv0Q0",
      classes: {
        button: "/app/components/Test.button?dhhHwAZl"
      },
      content: <<CSS
.\\/app\\/components\\/Test\\.button\\?dhhHwAZl{color:#f0f}
CSS
    ].merge(import?("/app/components/Test.css"))
  public def render
    H[
      :button,
      "Click me",
      **self.class.merge_props({ class: :__button }, { class: :button })
    ]
  end
end
Default = Test
Default::Styles.each { add_asset(Assets::Asset.build(_1.filename, _1.content)) }
