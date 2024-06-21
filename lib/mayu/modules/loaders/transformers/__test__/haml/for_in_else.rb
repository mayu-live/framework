# frozen_string_literal: true
class For_in_else < Mayu::Component::Base
  def self.module_path
    __FILE__
  end
  Self = self
  FILENAME = __FILE__
  Styles = Mayu::NullStyleSheet[self].merge(import?("for_in_else.css"))
  public def render
    [
      begin
        # SourceMapMark:1:aXRlbXMgPSAld1tmb28gYmFyIGJhel0=
        items = %w[foo bar baz]
        nil
      end,
      H[
        :ul,
        # SourceMapMark:3:Zm9yIGl0ZW0gaW4gaXRlbXM=
        for item in items
          H[
            :li,
            # SourceMapMark:4:aXRlbQ==,
            item,
            **self.class.merge_props({ class: :__li })
          ]
        end,
        **self.class.merge_props({ class: :__ul })
      ]
    ].flatten
  end
end
Default = For_in_else
Default::Styles.each do
  add_asset(Mayu::Assets::Generators::Text[_1.filename, _1.content])
end
