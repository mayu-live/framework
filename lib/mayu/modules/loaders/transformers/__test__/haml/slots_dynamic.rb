# frozen_string_literal: true
class Test < Mayu::Component::Base
  def self.module_path
    __FILE__
  end
  Self = self
  FILENAME = __FILE__
  Styles = Mayu::NullStyleSheet[self]
  public def render
    [
      begin
        # SourceMapMark:1:bmFtZSA9ICJmb28i
        name = "foo"
        nil
      end,
      H.slot(self, name) do
        H[:p, "Fallback content", **self.class.merge_props({ class: :__p })]
      end
    ].flatten
  end
end
Default = Test
Default::Styles.each { add_asset(Assets::Asset.build(_1.filename, _1.content)) }
