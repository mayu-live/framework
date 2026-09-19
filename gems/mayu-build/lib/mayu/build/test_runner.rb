# frozen_string_literal: true

require "klenod/test"

require_relative "../build"
require_relative "../test/minitest_adapter"

module Mayu
  module Build
    class TestRunner
      def initialize(root:, worker_command:, output: $stdout, error_output: $stderr, **options)
        @root = root
        @worker_command = worker_command
        @output = output
        @error_output = error_output
        @options = options
      end

      def call
        ::Klenod::Test::Runner.new(
          context: -> { configuration.context },
          execute: method(:execute),
          worker_command:,
          output:,
          error_output:,
          format_error: method(:format_error),
          **options
        ).call
      end

      private

      attr_reader :root, :worker_command, :output, :error_output, :options

      def configuration
        Configuration.new(root:, mode: :development)
      end

      def execute(context, test_paths)
        adapter = Test::MinitestAdapter.new(output:)
        loaded = true

        test_paths.each do |path|
          adapter.register(path, context.entry(path).exports)
        rescue => error
          error_output.puts format_error(error, context)
          loaded = false
        end

        (loaded && adapter.run) ? 0 : 1
      end

      def format_error(error, context)
        DevelopmentProvider.new(context).format_exception(error)
      end
    end
  end
end
