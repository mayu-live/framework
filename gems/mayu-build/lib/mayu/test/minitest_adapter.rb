# frozen_string_literal: true

require "minitest"
require "minitest/test"

require_relative "../test"
require_relative "minitest_reporter"

module Mayu
  module Test
    class MinitestAdapter
      def initialize(output: $stdout)
        @output = output
      end

      def register(path, exports)
        Class.new(Case) do
          include exports

          define_singleton_method(:name) { path }
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
