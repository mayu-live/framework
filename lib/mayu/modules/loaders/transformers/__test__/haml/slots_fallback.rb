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
      H.slot(self) do
        H[:p, "Fallback content", **self.class.merge_props({ class: :__p })]
      end,
      **self.class.merge_props({ class: :__div })
    ]
  end
end
Default = Test
Default::Styles.each { add_asset(Assets::Asset.build(_1.filename, _1.content)) }
