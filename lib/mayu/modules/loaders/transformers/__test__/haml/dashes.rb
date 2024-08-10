# frozen_string_literal: true
class Dashes < Mayu::Component::Base
  def self.module_path
    __FILE__
  end
  Self = self
  INLINE_STYLES = []
  Styles =
    Mayu::Component::StyleSheets.new(
      self,
      [*INLINE_STYLES, import?("./dashes.css")].compact
    )
  public def render
    H[
      :div,
      H[
        :svg,
        H[
          :line,
          **self.class.merge_props(
            { class: :__line },
            # SourceMapMark:3:eyJzdHJva2Utd2lkdGgiID0-IDIsfQ==,
            { stroke_width: 2 }
          )
        ],
        **self.class.merge_props({ class: :__svg })
      ],
      **self.class.merge_props({ class: :__div })
    ]
  end
end
Default = Dashes
Default::INLINE_STYLES.each do
  add_asset(Mayu::Assets::Generators::Text[_1.filename, _1.content])
end
