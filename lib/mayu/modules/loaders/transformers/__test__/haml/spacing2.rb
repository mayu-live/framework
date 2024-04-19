# frozen_string_literal: true
class Spacing2 < Mayu::Component::Base
  def self.module_path
    __FILE__
  end
  Self = self
  FILENAME = __FILE__
  Styles = Mayu::NullStyleSheet[self].merge(import?("spacing2.css"))
  public def render
    H[
      :div,
      H[:p, "Hello World", **self.class.merge_props({ class: :__p })],
      H[:p, "Hello World", **self.class.merge_props({ class: :__p })],
      H[:p, "Hello World", **self.class.merge_props({ class: :__p })],
      H[:p, "Hello World", **self.class.merge_props({ class: :__p })],
      **self.class.merge_props({ class: :__div })
    ]
  end
end
Default = Spacing2
Default::Styles.each { add_asset(Assets::Asset.build(_1.filename, _1.content)) }
