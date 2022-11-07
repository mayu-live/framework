# frozen_string_literal: true
# typed: strict

module Mayu
  module Resources
    module Resolver
      # https://bugs.ruby-lang.org/issues/15330
      # https://bugs.ruby-lang.org/issues/18841
      autoload :Static, File.join(__dir__, "resolver", "static")
      autoload :Filesystem, File.join(__dir__, "resolver", "filesystem")
    end
  end
end
