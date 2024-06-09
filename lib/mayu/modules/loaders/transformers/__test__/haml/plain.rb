# frozen_string_literal: true
class Plain < Mayu::Component::Base
  def self.module_path
    __FILE__
  end
  Self = self
  FILENAME = __FILE__
  Styles = Mayu::NullStyleSheet[self].merge(import?("plain.css"))
  public def render
    [
      H[
        :pre,
        <<~PLAIN_3a33e85b1163f921b28fe81f304cf142fa2cffbb0a76a9262e2313211716e37f,
hello

world
PLAIN_3a33e85b1163f921b28fe81f304cf142fa2cffbb0a76a9262e2313211716e37f
        **self.class.merge_props({ class: :__pre })
      ],
      H[:p, "asd", **self.class.merge_props({ class: :__p })]
    ].flatten
  end
end
Default = Plain
Default::Styles.each do
  add_asset(Mayu::Modules::Generators::Text[_1.filename, _1.content])
end