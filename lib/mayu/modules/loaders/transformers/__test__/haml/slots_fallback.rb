# frozen_string_literal: true
class Slots_fallback < Mayu::Component::Base
  def self.module_path
    __FILE__
  end
  Self = self
  INLINE_STYLES = []
  Styles =
    Mayu::Component::StyleSheets.new(
      self,
      [*INLINE_STYLES, import?("./slots_fallback.css")].compact
    )
  public def render
    H[
      :div,
      H.slot(self) do
        H[:p, "Fallback content", **self.class.merge_props({ class: :__p })]
      end,
      **self.class.merge_props({ class: :__div })
    ]
  end
end
Default = Slots_fallback
Default::INLINE_STYLES.each do
  add_asset(Mayu::Assets::Generators::Text[_1.filename, _1.content])
end
