# frozen_string_literal: true
class Test < Mayu::Component::Base
  def self.module_path
    __FILE__
  end
  Self = self
  FILENAME = __FILE__
  Styles =
    Mayu::StyleSheet[
      source_filename: "/app/components/Test.haml (inline css)",
      content_hash: "bqEaytGziGYN7IPb40YU5_w9vSeOTU-lSPeEZ8-fWPs",
      classes: {
        default: "/app/components/Test.default?zMcJqVrb"
      },
      content: <<CSS
.\\/app\\/components\\/Test\\.default\\?zMcJqVrb{font-weight:700}
CSS
    ].merge(import?("/app/components/Test.css"))
  begin
    # SourceMapMark:2:ZGVmIGluaXRpYWxpemU=
    def initialize
      # SourceMapMark:2:ZGVmIGluaXRpYWxpemU= # SourceMapMark:3:QGZvbyA9ICRmb28=
      update!(
        # SourceMapMark:3:QGZvbyA9ICRmb28=
        @foo = @__props[:foo]
      )
    end
    nil
  end
  public def render
    [
      begin
        # SourceMapMark:7:Y2xhc3NuYW1lID0gJGNsYXNzIHx8IDpkZWZhdWx0
        classname = @__props[:class] || :default
        nil
      end,
      H[
        :p,
        "hello",
        **self.class.merge_props(
          { class: :__p },
          # SourceMapMark:9:eyJjbGFzcyIgPT4gY2xhc3NuYW1lLH0=,
          { class: classname }
        )
      ]
    ].flatten
  end
end
Default = Test
Default::Styles.each { add_asset(Assets::Asset.build(_1.filename, _1.content)) }
