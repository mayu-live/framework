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
      H[
        :pre,
        <<~PLAIN_0d28776580b49b522a44d225bc27b05f207b810a69b97e9d06bda26431e0c9f3,
hello

world
PLAIN_0d28776580b49b522a44d225bc27b05f207b810a69b97e9d06bda26431e0c9f3
        **self.class.merge_props({ class: :__pre })
      ],
      H[:p, "asd", **self.class.merge_props({ class: :__p })]
    ].flatten
  end
end
Default = Test
Default::Styles.each { add_asset(Assets::Asset.build(_1.filename, _1.content)) }
