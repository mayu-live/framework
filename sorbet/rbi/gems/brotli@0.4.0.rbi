# typed: true

# DO NOT EDIT MANUALLY
# This is an autogenerated file for types exported from the `brotli` gem.
# Please instead update this file by running `bin/tapioca gem brotli`.

# source://brotli-0.4.0/lib/brotli/version.rb:1
module Brotli
  class << self
    def deflate(*_arg0); end
    def inflate(_arg0); end
    def version; end
  end
end

class Brotli::Error < ::StandardError; end

# source://brotli-0.4.0/lib/brotli/version.rb:2
Brotli::VERSION = T.let(T.unsafe(nil), String)

class Brotli::Writer
  def initialize(*_arg0); end

  def close; end
  def finish; end
  def flush; end
  def write(_arg0); end
end
