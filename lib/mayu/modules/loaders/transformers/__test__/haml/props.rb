# frozen_string_literal: true
class Props < Mayu::Component::Base
  def self.module_path
    __FILE__
  end
  Self = self
  FILENAME = __FILE__
  Styles =
    Mayu::Component::StyleSheets.new(self, [import?("./props.css")].compact)
  public def render
    H[
      :div,
      H[
        :h1,
        # SourceMapMark:2:JHRpdGxl,
        @__props[:title],
        **self.class.merge_props({ class: :__h1 })
      ],
      H[
        :h1,
        # SourceMapMark:3:ImhlaiAjeyR0aXRsZVsxMjNdfSBhc2Qi,
        "hej #{@__props[:title][123]} asd",
        **self.class.merge_props({ class: :__h1 })
      ],
      H[
        :h2,
        # SourceMapMark:4:JH4=,
        $~,
        **self.class.merge_props({ class: :__h2 })
      ],
      **self.class.merge_props(
        { class: :__div },
        # SourceMapMark:1:eyJjbGFzcyIgPT4gJGNsYXNzLH0=,
        { class: @__props[:class] }
      )
    ]
  end
end
Default = Props
Default::Styles.each do
  add_asset(Mayu::Assets::Generators::Text[_1.filename, _1.content])
end
