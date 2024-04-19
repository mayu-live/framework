# frozen_string_literal: true
class Comments < Mayu::Component::Base
  def self.module_path
    __FILE__
  end
  Self = self
  FILENAME = __FILE__
  Styles = Mayu::NullStyleSheet[self].merge(import?("comments.css"))
  public def render
    H[
      :div,
      H[:foo, **self.class.merge_props({ class: :__foo })],
      H[:bar, **self.class.merge_props({ class: :__bar })],
      **self.class.merge_props({ class: :__div })
    ]
  end
end
Default = Comments
Default::Styles.each { add_asset(Assets::Asset.build(_1.filename, _1.content)) }
