# frozen_string_literal: true
class Object_ref_as_key < Mayu::Component::Base
  def self.module_path
    __FILE__
  end
  Self = self
  FILENAME = __FILE__
  Styles = Mayu::NullStyleSheet[self].merge(import?("object_ref_as_key.css"))
  public def render
    H[:div, **self.class.merge_props({ class: :__div }, { key: ["hello"] })]
  end
end
Default = Object_ref_as_key
Default::Styles.each do
  add_asset(Mayu::Modules::Generators::Text[_1.filename, _1.content])
end
