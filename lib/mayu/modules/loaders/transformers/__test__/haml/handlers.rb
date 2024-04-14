# frozen_string_literal: true
class Test < Mayu::Component::Base
  def self.module_path
    __FILE__
  end
  Self = self
  FILENAME = __FILE__
  Styles = Mayu::NullStyleSheet[self]
  begin
    # SourceMapMark:2:ZGVmIGhhbmRsZV9jbGljayhlKQ==
    def handle_click(e)
      # SourceMapMark:3:Q29uc29sZS5sb2dnZXIuaW5mbyhzZWxmLCBlKQ== # SourceMapMark:3:Q29uc29sZS5sb2dnZXIuaW5mbyhzZWxmLCBlKQ==
      Console.logger.info(self, e)
    end
    nil
  end
  public def render
    H[
      :button,
      "Click me",
      **self.class.merge_props(
        { class: :__button },
        # SourceMapMark:6:eyJvbmNsaWNrIiA9PiBoYW5kbGVfY2xpY2ssfQ==,
        { onclick: H.callback(self, :handle_click) }
      )
    ]
  end
end
Default = Test
Default::Styles.each { add_asset(Assets::Asset.build(_1.filename, _1.content)) }
