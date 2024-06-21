# frozen_string_literal: true
class Multiple_ruby_filters < Mayu::Component::Base
  def self.module_path
    __FILE__
  end
  Self = self
  FILENAME = __FILE__
  Styles =
    Mayu::StyleSheet[
      source_filename: "multiple_ruby_filters.haml (inline css)",
      content_hash: "o8vRkv9EqLa-SClq1zcq3n32AmbUcxJtrPsk5z_TTvI",
      classes: {
        default: "multiple_ruby_filters.default?zMcJqVrb"
      },
      content: <<CSS
.multiple_ruby_filters\\.default\\?zMcJqVrb{font-weight:700}
CSS
    ].merge(import?("multiple_ruby_filters.css"))
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
Default = Multiple_ruby_filters
Default::Styles.each do
  add_asset(Mayu::Assets::Generators::Text[_1.filename, _1.content])
end
