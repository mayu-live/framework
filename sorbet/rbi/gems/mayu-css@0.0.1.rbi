# typed: true

# DO NOT EDIT MANUALLY
# This is an autogenerated file for types exported from the `mayu-css` gem.
# Please instead update this file by running `bin/tapioca gem mayu-css`.

# source://mayu-css//lib/mayu/css/version.rb#3
module Mayu; end

# source://mayu-css//lib/mayu/css/version.rb#4
module Mayu::CSS
  class << self
    def minify(_arg0, _arg1); end
    def serialize(_arg0, _arg1); end
    def transform(_arg0, _arg1); end
  end
end

# source://mayu-css//lib/mayu/css.rb#15
class Mayu::CSS::Error < ::StandardError; end

# source://mayu-css//lib/mayu/css.rb#17
class Mayu::CSS::TransformResult
  def classes; end
  def code; end

  # source://mayu-css//lib/mayu/css.rb#18
  def dependencies; end

  def elements; end
  def serialized_dependencies; end
end

# source://mayu-css//lib/mayu/css/version.rb#5
Mayu::CSS::VERSION = T.let(T.unsafe(nil), String)

# source://mayu-live/0.0.0/lib/mayu/version.rb#5
Mayu::VERSION = T.let(T.unsafe(nil), String)