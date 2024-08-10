# frozen_string_literal: true
class Slots < Mayu::Component::Base
  def self.module_path
    __FILE__
  end
  Self = self
  INLINE_STYLES = []
  Styles =
    Mayu::Component::StyleSheets.new(
      self,
      [*INLINE_STYLES, import?("./slots.css")].compact
    )
  public def render
    H[
      :body,
      H[:main, H.slot(self), **self.class.merge_props({ class: :__main })],
      H[
        :footer,
        H.slot(self, "footer"),
        **self.class.merge_props({ class: :__footer })
      ],
      **self.class.merge_props({ class: :__body })
    ]
  end
end
Default = Slots
Default::INLINE_STYLES.each do
  add_asset(Mayu::Assets::Generators::Text[_1.filename, _1.content])
end
