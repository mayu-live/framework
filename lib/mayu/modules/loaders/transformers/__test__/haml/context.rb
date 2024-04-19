# frozen_string_literal: true
class Context < Mayu::Component::Base
  def self.module_path
    __FILE__
  end
  Self = self
  FILENAME = __FILE__
  Styles = Mayu::NullStyleSheet[self]
  begin
    # SourceMapMark:2:ZGVmIGluY3JlYXNlX2NvbnRleHRfdmFy
    def increase_context_var
      # SourceMapMark:3:QEBjb250ZXh0X3ZhciArPSAx # SourceMapMark:3:QEBjb250ZXh0X3ZhciArPSAx
      @__context[:context_var] += 1
    end
    nil
  end
  public def render
    H[
      :div,
      H[
        :p,
        # SourceMapMark:6:QEBjb250ZXh0X3Zhcg==,
        @__context[:context_var],
        **self.class.merge_props({ class: :__p })
      ],
      **self.class.merge_props({ class: :__div })
    ]
  end
end
Default = Context
Default::Styles.each { add_asset(Assets::Asset.build(_1.filename, _1.content)) }
