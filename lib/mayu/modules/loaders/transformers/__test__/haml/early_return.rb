# frozen_string_literal: true
class Early_return < Mayu::Component::Base
  def self.module_path
    __FILE__
  end
  Self = self
  FILENAME = __FILE__
  Styles =
    Mayu::Component::StyleSheets.new(
      self,
      [import?("./early_return.css")].compact
    )
  public def render
    [
      begin
        # SourceMapMark:1:aWYgdHJ1ZQ==
        if true
          # SourceMapMark:2:cmV0dXJu
          return(
            H[
              :div,
              **self.class.merge_props({ class: :__div }, { class: :foo })
            ]
          )
        end
        nil
      end,
      H[:div, **self.class.merge_props({ class: :__div }, { class: :bar })]
    ].flatten
  end
end
Default = Early_return
Default::Styles.each do
  add_asset(Mayu::Assets::Generators::Text[_1.filename, _1.content])
end
