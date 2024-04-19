# frozen_string_literal: true
class Whitespace_preservation < Mayu::Component::Base
  def self.module_path
    __FILE__
  end
  Self = self
  FILENAME = __FILE__
  Styles = Mayu::NullStyleSheet[self]
  public def render
    # SourceMapMark:1:IkZvb1xuPHByZT5CYXJcbkJhejwvcHJlPiI=
    "Foo\n<pre>Bar\nBaz</pre>"
  end
end
Default = Whitespace_preservation
Default::Styles.each { add_asset(Assets::Asset.build(_1.filename, _1.content)) }
