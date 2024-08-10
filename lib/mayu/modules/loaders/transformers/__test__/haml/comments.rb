# frozen_string_literal: true
class Comments < Mayu::Component::Base
  def self.module_path
    __FILE__
  end
  Self = self
  INLINE_STYLES = []
  Styles =
    Mayu::Component::StyleSheets.new(
      self,
      [*INLINE_STYLES, import?("./comments.css")].compact
    )
  public def render
    H[
      :div,
      H[:foo, **self.class.merge_props({ class: :__foo })],
      H[:bar, **self.class.merge_props({ class: :__bar })],
      **self.class.merge_props({ class: :__div })
    ]
  end
end
Default = Comments
Default::INLINE_STYLES.each do
  add_asset(Mayu::Assets::Generators::Text[_1.filename, _1.content])
end
