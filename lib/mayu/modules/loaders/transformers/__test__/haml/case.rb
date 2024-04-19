# frozen_string_literal: true
class Case < Mayu::Component::Base
  def self.module_path
    __FILE__
  end
  Self = self
  FILENAME = __FILE__
  Styles = Mayu::NullStyleSheet[self].merge(import?("case.css"))
  public def render
    H[
      :div,
      case props[:value]
      when "foo"
        H[:p, "Foo", **self.class.merge_props({ class: :__p })]
      when "bar"
        H[:p, "Bar", **self.class.merge_props({ class: :__p })]
      else
        H[:p, "Other", **self.class.merge_props({ class: :__p })]
      end,
      **self.class.merge_props({ class: :__div })
    ]
  end
end
Default = Case
Default::Styles.each { add_asset(Assets::Asset.build(_1.filename, _1.content)) }
