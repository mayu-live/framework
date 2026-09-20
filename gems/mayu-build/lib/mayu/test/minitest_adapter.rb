# frozen_string_literal: true

require "minitest"
require "minitest/test"

require_relative "../test"
require_relative "minitest_reporter"

module Mayu
  module Test
    class MinitestAdapter
      def initialize(output: $stdout, module_provider: nil)
        @output = output
        @module_provider = module_provider
      end

      def register(path, exports)
        module_provider = @module_provider
        Class.new(Case) do
          include exports

          define_singleton_method(:name) { path }
          define_method(:__test_module_provider) { module_provider }
          private :__test_module_provider
        end
      end

      def run(arguments = [])
        unless Minitest.extensions.include?(MinitestReporterPlugin)
          Minitest.register_plugin(MinitestReporterPlugin)
        end
        MinitestReporterPlugin.output = @output
        Minitest.run(arguments)
      ensure
        MinitestReporterPlugin.output = nil
      end
    end
  end
end
