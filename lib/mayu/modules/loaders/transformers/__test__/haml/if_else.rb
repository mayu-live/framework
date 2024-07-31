# frozen_string_literal: true
class If_else < Mayu::Component::Base
  def self.module_path
    __FILE__
  end
  Self = self
  FILENAME = __FILE__
  Styles =
    Mayu::Component::StyleSheets.new(self, [import?("./if_else.css")].compact)
  begin
    # setup
    nil
  end
  public def render
    if true
      H[:div, **self.class.merge_props({ class: :__div }, { class: :foo })]
    else
      H[:div, **self.class.merge_props({ class: :__div }, { class: :bar })]
    end
  end
end
Default = If_else
Default::Styles.each do
  add_asset(Mayu::Assets::Generators::Text[_1.filename, _1.content])
end
