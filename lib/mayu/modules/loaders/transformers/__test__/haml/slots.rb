# frozen_string_literal: true
class Slots < Mayu::Component::Base
  def self.module_path
    __FILE__
  end
  Self = self
  FILENAME = __FILE__
  Styles = Mayu::NullStyleSheet[self].merge(import?("slots.css"))
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
Default::Styles.each do
  add_asset(Mayu::Assets::Generators::Text[_1.filename, _1.content])
end
