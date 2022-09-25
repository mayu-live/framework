# typed: strict
# frozen_string_literal: true

require_relative "base"
require_relative "../environment"

module Mayu
  module Commands
    class Build < Base
      extend T::Sig

      sig { params(argv: T::Array[String]).void }
      def call(argv)
        Console
          .logger
          .measure("Building") do
            environment = Environment.new(configuration)
            resources = environment.resources

            environment.routes.each { |route| p route }

            filename = "app.mayu-bundle"
            puts "\e[34m#{resources.mermaid_url}\e[0m"
            puts "\e[33mGenerate assets\e[0m"
            resources.generate_assets(File.join(__dir__, "assets"))

            puts "\e[33mWrite #{filename}\e[0m"
            File.write(filename, resources.dump)
          end
      end
    end
  end
end
