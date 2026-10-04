# frozen_string_literal: true

require "minitest/test"

module Mayu
  module Test
    class Case < Minitest::Test
      include Helpers

      def run
        Sync do
          super
        ensure
          test_pages.reverse_each(&:stop)
          test_pages.clear
          Fiber[:current_test_page] = nil
        end
      end

      private

      def test_pages
        @test_pages ||= []
      end

      def __register_test_page(page)
        test_pages << page
      end

      def __unregister_test_page(page)
        test_pages.delete(page)
      end
    end
  end
end
