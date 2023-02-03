# typed: true

# DO NOT EDIT MANUALLY
# This is an autogenerated file for types exported from the `mayucss` gem.
# Please instead update this file by running `bin/tapioca gem mayucss`.

# source://mayucss//lib/mayucss/version.rb#3
module MayuCSS
  class << self
    def minify(_arg0, _arg1); end
    def serialize(_arg0, _arg1); end
    def transform(_arg0, _arg1); end
  end
end

# source://mayucss//lib/mayucss.rb#14
class MayuCSS::Error < ::StandardError; end

# source://mayucss//lib/mayucss.rb#16
class MayuCSS::TransformResult
  def classes; end
  def code; end

  # source://mayucss//lib/mayucss.rb#17
  def dependencies; end

  def elements; end
  def serialized_dependencies; end
end

# source://mayucss//lib/mayucss/version.rb#4
MayuCSS::VERSION = T.let(T.unsafe(nil), String)
