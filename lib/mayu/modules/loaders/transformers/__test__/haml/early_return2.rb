# frozen_string_literal: true
class Early_return2 < Mayu::Component::Base
  def self.module_path
    __FILE__
  end
  Self = self
  FILENAME = __FILE__
  Styles = Mayu::NullStyleSheet[self].merge(import?("early_return2.css"))
  public def render
    [
      # SourceMapMark:1:cmV0dXJuIGlmIHByb3BzWzpmb29d
      if # SourceMapMark:2:cHJvcHNbOmZvb10=
         props[:foo]
        return(
          H[:div, **self.class.merge_props({ class: :__div }, { class: :foo })]
        )
      end,
      H[:div, **self.class.merge_props({ class: :__div }, { class: :bar })]
    ].flatten
  end
end
Default = Early_return2
Default::Styles.each { add_asset(Assets::Asset.build(_1.filename, _1.content)) }
