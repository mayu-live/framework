# frozen_string_literal: true
class Slots_dynamic < Mayu::Component::Base
  def self.module_path
    __FILE__
  end
  Self = self
  INLINE_STYLES = []
  Styles =
    Mayu::Component::StyleSheets.new(
      self,
      [*INLINE_STYLES, import?("./slots_dynamic.css")].compact
    )
  public def render
    [
      begin
        # SourceMapMark:1:bmFtZSA9ICJmb28i
        name = "foo"
        nil
      end,
      H.slot(self, name) do
        H[:p, "Fallback content", **self.class.merge_props({ class: :__p })]
      end
    ].flatten
  end
end
Default = Slots_dynamic
Default::INLINE_STYLES.each do
  add_asset(Mayu::Assets::Generators::Text[_1.filename, _1.content])
end
