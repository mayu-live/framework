module Mayu
  module Runtime
    autoload :Engine, File.join(__dir__, "runtime", "engine")

    def self.init(descriptor, runtime_js:)
      Engine.new(descriptor, runtime_js:)
    end
  end
end
