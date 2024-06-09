# frozen_string_literal: true
class Spacing < Mayu::Component::Base
  def self.module_path
    __FILE__
  end
  Self = self
  FILENAME = __FILE__
  Styles = Mayu::NullStyleSheet[self].merge(import?("spacing.css"))
  public def render
    H[
      :p,
      "There should be no space on the left of this text. But there should be one between this line and the previous line. ",
      H[
        :a,
        "And there should be spaces before this link",
        **self.class.merge_props({ class: :__a }, { href: "/" })
      ],
      ". Was there?",
      **self.class.merge_props({ class: :__p })
    ]
  end
end
Default = Spacing
Default::Styles.each do
  add_asset(Mayu::Modules::Generators::Text[_1.filename, _1.content])
end
