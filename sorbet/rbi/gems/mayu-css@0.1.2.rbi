# typed: true

# DO NOT EDIT MANUALLY
# This is an autogenerated file for types exported from the `mayu-css` gem.
# Please instead update this file by running `bin/tapioca gem mayu-css`.

# source://mayu-css//lib/mayu/css/version.rb#3
module Mayu; end

# source://mayu-css//lib/mayu/css/version.rb#4
module Mayu::CSS
  class << self
    def ext_minify(_arg0, _arg1); end
    def ext_serialize(_arg0, _arg1); end
    def ext_transform(_arg0, _arg1, _arg2); end

    # source://mayu-css//lib/mayu/css.rb#107
    def minify(file, code); end

    # source://mayu-css//lib/mayu/css.rb#110
    def serialize(file, code); end

    # source://mayu-css//lib/mayu/css.rb#104
    def transform(file, code, minify: T.unsafe(nil)); end
  end
end

class Mayu::CSS::ComposeDependency < ::Data
  def name; end
  def specifier; end

  class << self
    def [](*_arg0); end
    def inspect; end
    def members; end
    def new(*_arg0); end
  end
end

class Mayu::CSS::ComposeLocal < ::Data
  def name; end

  class << self
    def [](*_arg0); end
    def inspect; end
    def members; end
    def new(*_arg0); end
  end
end

# source://mayu-css//lib/mayu/css.rb#15
class Mayu::CSS::Error < ::StandardError; end

class Mayu::CSS::Export < ::Data
  def composes; end
  def name; end
  def referenced?; end

  class << self
    def [](*_arg0); end
    def inspect; end
    def members; end
    def new(*_arg0); end
  end
end

class Mayu::CSS::ExtTransformResult
  def classes; end
  def code; end
  def elements; end
  def serialized_dependencies; end
  def serialized_exports; end
  def source_map; end
end

class Mayu::CSS::ImportDependency < ::Data
  def loc; end
  def media; end
  def placeholder; end
  def supports; end
  def url; end

  class << self
    def [](*_arg0); end
    def inspect; end
    def members; end
    def new(*_arg0); end
  end
end

class Mayu::CSS::Loc < ::Data
  def end; end
  def file_path; end
  def start; end

  class << self
    def [](*_arg0); end

    # source://mayu-css//lib/mayu/css.rb#27
    def from_ext(data); end

    def inspect; end
    def members; end
    def new(*_arg0); end
  end
end

# source://mayu-css//lib/mayu/css.rb#16
class Mayu::CSS::ParseError < ::Mayu::CSS::Error; end

class Mayu::CSS::Pos < ::Data
  def column; end
  def line; end

  class << self
    def [](*_arg0); end

    # source://mayu-css//lib/mayu/css.rb#36
    def from_ext(data); end

    def inspect; end
    def members; end
    def new(*_arg0); end
  end
end

class Mayu::CSS::SerializeResult < ::Data
  def license_comments; end
  def rules; end
  def source_map_urls; end
  def sources; end

  class << self
    def [](*_arg0); end

    # source://mayu-css//lib/mayu/css.rb#93
    def from_ext(data); end

    def inspect; end
    def members; end
    def new(*_arg0); end
  end
end

class Mayu::CSS::TransformResult < ::Data
  def classes; end
  def code; end

  # source://mayu-css//lib/mayu/css.rb#84
  def code_with_source_map; end

  def dependencies; end
  def elements; end
  def exports; end

  # source://mayu-css//lib/mayu/css.rb#78
  def replace_dependencies; end

  def source_map; end

  class << self
    def [](*_arg0); end

    # source://mayu-css//lib/mayu/css.rb#41
    def from_ext(data); end

    def inspect; end
    def members; end
    def new(*_arg0); end
  end
end

class Mayu::CSS::UrlDependency < ::Data
  def loc; end
  def placeholder; end
  def url; end

  class << self
    def [](*_arg0); end
    def inspect; end
    def members; end
    def new(*_arg0); end
  end
end

# source://mayu-css//lib/mayu/css/version.rb#5
Mayu::CSS::VERSION = T.let(T.unsafe(nil), String)
