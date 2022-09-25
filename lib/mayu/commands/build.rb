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
            environment.init_js
            resources = environment.resources

            components = []

            environment.routes.each do |route|
              route.layouts.each do |layout|
                components.push(File.join("/app", "pages", layout))
              end

              components.push(File.join("/app", "pages", route.template))
            end

            components.each do |component|
              resources.load_resource(component).type.component
            end

            puts "\e[34m#{resources.mermaid_url}\e[0m"

            assets_dir = environment.path(:assets)
            files_to_remove = Dir.glob(File.join(assets_dir, "*"))

            unless files_to_remove.empty?
              puts "\e[33mRemoving #{files_to_remove.size} files from #{assets_dir}\e[0m"
              FileUtils.rm(files_to_remove)
            end

            puts "\e[33mGenerate assets\e[0m"
            resources.generate_assets(assets_dir)

            filename = "app.mayu-bundle"
            puts "\e[33mWrite #{filename}\e[0m"
            File.write(filename, resources.dump)
          end
      end
    end
  end
end
