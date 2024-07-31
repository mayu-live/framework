# frozen_string_literal: true
class Handlers < Mayu::Component::Base
  def self.module_path
    __FILE__
  end
  Self = self
  FILENAME = __FILE__
  Styles =
    Mayu::Component::StyleSheets.new(self, [import?("./handlers.css")].compact)
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
Default = Handlers
Default::Styles.each do
  add_asset(Mayu::Assets::Generators::Text[_1.filename, _1.content])
end
