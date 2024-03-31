module Mayu
  module Modules
    module Rules
      Rule = Data.define(:test, :use, :options) do
        def self.[](test, use, **options) =
          new(test, use, options)
        def match?(path) =
          test.match?(path)
        def call(loading_file) =
          use.call(loading_file)
      end
    end
  end
end