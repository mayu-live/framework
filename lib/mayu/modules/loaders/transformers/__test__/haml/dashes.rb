# frozen_string_literal: true
class Dashes < Mayu::Component::Base
  def self.module_path
    __FILE__
  end
  Self = self
  FILENAME = __FILE__
  Styles = Mayu::NullStyleSheet[self]
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
Default::Styles.each { add_asset(Assets::Asset.build(_1.filename, _1.content)) }
