# frozen_string_literal: true
#
# Copyright Andreas Alin <andreas.alin@gmail.com>
# License: AGPL-3.0

module Mayu
  module Modules
    module Generators
      autoload :Image, File.join(__dir__, "generators", "image")
      autoload :Text, File.join(__dir__, "generators", "text")
    end
  end
end
