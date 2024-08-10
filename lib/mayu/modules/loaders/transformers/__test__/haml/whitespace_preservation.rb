# frozen_string_literal: true
class Whitespace_preservation < Mayu::Component::Base
  def self.module_path
    __FILE__
  end
  Self = self
  INLINE_STYLES = []
  Styles =
    Mayu::Component::StyleSheets.new(
      self,
      [*INLINE_STYLES, import?("./whitespace_preservation.css")].compact
    )
  public def render
    # SourceMapMark:1:IkZvb1xuPHByZT5CYXJcbkJhejwvcHJlPiI=
    "Foo\n<pre>Bar\nBaz</pre>"
  end
end
Default = Whitespace_preservation
Default::INLINE_STYLES.each do
  add_asset(Mayu::Assets::Generators::Text[_1.filename, _1.content])
end
