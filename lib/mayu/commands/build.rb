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
            registry = Mayu::Resources::Registry.new(root: configuration.root)
            filename = "registry.bundle"
            puts "\e[34m#{registry.mermaid_url}\e[0m"
            puts "\e[33mGenerate assets\e[0m"
            registry.generate_assets(File.join(__dir__, "assets"))

            puts "\e[33mWrite #{filename}\e[0m"
            File.write(filename, registry.dump)
          end
      end
    end
  end
end
