# frozen_string_literal: true
class Test < Mayu::Component::Base
  def self.module_path
    __FILE__
  end
  Self = self
  FILENAME = __FILE__
  Styles = Mayu::NullStyleSheet[self]
  begin
    # setup
  end
  public def render
    if true
      H[:div, **self.class.merge_props({ class: :__div }, { class: :foo })]
    else
      H[:div, **self.class.merge_props({ class: :__div }, { class: :bar })]
    end
  end
end
Default = Test
Default::Styles.each { add_asset(Assets::Asset.build(_1.filename, _1.content)) }
