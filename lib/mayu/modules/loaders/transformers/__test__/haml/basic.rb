# frozen_string_literal: true
class Basic < Mayu::Component::Base
  def self.module_path
    __FILE__
  end
  Self = self
  FILENAME = __FILE__
  Styles = Mayu::NullStyleSheet[self].merge(import?("basic.css"))
  public def render
    H[:p, "Hello world", **self.class.merge_props({ class: :__p })]
  end
end
Default = Basic
Default::Styles.each { add_asset(Assets::Asset.build(_1.filename, _1.content)) }
