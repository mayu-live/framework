# frozen_string_literal: true
class Object_ref_as_key < Mayu::Component::Base
  def self.module_path
    __FILE__
  end
  Self = self
  INLINE_STYLES = []
  Styles =
    Mayu::Component::StyleSheets.new(
      self,
      [*INLINE_STYLES, import?("./object_ref_as_key.css")].compact
    )
  public def render
    H[:div, **self.class.merge_props({ class: :__div }, { key: ["hello"] })]
  end
end
Default = Object_ref_as_key
Default::INLINE_STYLES.each do
  add_asset(Mayu::Assets::Generators::Text[_1.filename, _1.content])
end
