# frozen_string_literal: true
class Test < Mayu::Component::Base
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
        :div,
        # SourceMapMark:3:ImZvbyAje2Jhcn0gYmF6Ig==
        "foo #{bar} baz",
        **self.class.merge_props({ class: :__div })
      ],
      H[
        :div,
        # SourceMapMark:4:ImZvbyAje2Jhcn0gYmF6Ig==,
        "foo #{bar} baz",
        **self.class.merge_props({ class: :__div })
      ],
      H[
        :div,
        # SourceMapMark:5:ImZvbyAje2Jhcn0gYmF6Ig==,
        "foo #{bar} baz",
        **self.class.merge_props({ class: :__div })
      ],
      H[
        :div,
        if bar
          # SourceMapMark:8:ImxvbCAje2JvbGx9IHBvbGxlIg==
          "lol #{boll} polle"
        end,
        **self.class.merge_props({ class: :__div })
      ],
      **self.class.merge_props({ class: :__div })
    ]
  end
end
Default = Test
Default::Styles.each { add_asset(Assets::Asset.build(_1.filename, _1.content)) }
