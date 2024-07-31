# frozen_string_literal: true
class Spacing3 < Mayu::Component::Base
  def self.module_path
    __FILE__
  end
  Self = self
  FILENAME = __FILE__
  Styles =
    Mayu::Component::StyleSheets.new(self, [import?("./spacing3.css")].compact)
  public def render
    H[
      :p,
      # SourceMapMark:2:IkJsYWJsYSAje2FzZH0i
      "Blabla #{asd}",
      " ",
      H[:a, "hopp", **self.class.merge_props({ class: :__a }, { href: "asd" })],
      **self.class.merge_props({ class: :__p })
    ]
  end
end
Default = Spacing3
Default::Styles.each do
  add_asset(Mayu::Assets::Generators::Text[_1.filename, _1.content])
end
