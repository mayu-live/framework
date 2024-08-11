# frozen_string_literal: true
class HelloWorld < Mayu::Component::Base
  def self.module_path
    __FILE__
  end
  Self = self
  INLINE_STYLES = [
    begin
      Mayu::StyleSheet[
        source_filename: "HelloWorld.haml.css",
        content_hash: "mJspXVoY5P2oKgeSOglNdPcM8Woi0kqUxHo3h1Og7kg",
        classes: {
          __button: "HelloWorld.haml_button?N2Q7U-wl"
        },
        content: <<CSS
.HelloWorld\\.haml_button\\?N2Q7U-wl{background:#ccc;border:1px solid #000;border-radius:3px}
CSS
      ]
    end
  ]
  Styles =
    Mayu::Component::StyleSheets.new(
      self,
      [*INLINE_STYLES, import?("./HelloWorld.css")].compact
    )
  begin
    # SourceMapMark:2:ZGVmIGluaXRpYWxpemU=
    def initialize
      # SourceMapMark:2:ZGVmIGluaXRpYWxpemU= # SourceMapMark:3:QGNvdW50ID0gJGluaXRpYWxfY291bnQgfHwgMA==
      update!(
        # SourceMapMark:3:QGNvdW50ID0gJGluaXRpYWxfY291bnQgfHwgMA==
        @count = @__props[:initial_count] || 0
      )
    end

    # SourceMapMark:6:ZGVmIGhhbmRsZV9pbmNyZW1lbnQ=
    def handle_increment
      # SourceMapMark:2:ZGVmIGluaXRpYWxpemU= # SourceMapMark:7:QGNvdW50ICs9IDE=
      update!(@count += 1)
    end
    nil
  end
  public def render
    Mayu::Descriptors::H[
      :section,
      Mayu::Descriptors::H[
        :h2,
        "Counter",
        **self.class.merge_props({ class: :__h2 })
      ],
      Mayu::Descriptors::H[
        :button,
        "Increment",
        **self.class.merge_props(
          { class: :__button },
          # SourceMapMark:12:eyJvbmNsaWNrIiA9PiBoYW5kbGVfaW5jcmVtZW50LH0=,
          { onclick: Mayu::Descriptors::H.callback(self, :handle_increment) }
        )
      ],
      Mayu::Descriptors::H[
        :button,
        "Decrement",
        **self.class.merge_props(
          { class: :__button },
          # SourceMapMark:14:eyJvbmNsaWNrIiA9PiBoYW5kbGVfZGVjcmVtZW50LH0=,
          { onclick: Mayu::Descriptors::H.callback(self, :handle_decrement) }
        )
      ],
      **self.class.merge_props({ class: :__section })
    ]
  end
end
Default = HelloWorld
Default::INLINE_STYLES.each do
  add_asset(Mayu::Assets::Generators::Text[_1.filename, _1.content])
end
