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
        require "fileutils"

        Async do
          started_at = Time.now.to_f

          metrics = AppMetrics.setup(Prometheus::Client.registry)
          environment = Environment.new(configuration, metrics)
          environment.init_js
          resources = environment.resources

          components = []

          components.push(File.join("/app", "root"))

          environment.routes.each do |route|
            route.layouts.each do |layout|
              components.push(File.join("/app", "pages", layout))
            end

            components.push(File.join("/app", "pages", route.template))
          end

          components.each do |component|
            resources.load_resource(component).type.component
          end

          File.write("app-graph.md", <<~EOF)
            ```mermaid
            #{resources.dependency_graph.to_mermaid_source.chomp}
            ```
          EOF

          mermaid_url = resources.mermaid_url

          assets_dir = environment.path(:assets)
          FileUtils.mkdir_p(assets_dir)
          files_to_remove = Dir.glob(File.join(assets_dir, "*"))

          unless files_to_remove.empty?
            puts "\e[33mRemoving #{files_to_remove.size} files from #{assets_dir}\e[0m"
            FileUtils.rm(files_to_remove)
          end

          puts "\e[35mGenerating assets\e[0m"

          resources.generate_assets(
            assets_dir,
            concurrency: `nproc`.to_i.nonzero? || 8,
            forever: false
          ).wait

          filename = configuration.paths.bundle_filename
          puts "\e[35mWriting \e[1m#{filename}\e[0m"
          File.write(filename, resources.dump)

          puts
          puts format(
                 "\e[36mBuilt app in \e[1m%.2f seconds\e[0m",
                 Time.now.to_f - started_at
               )

          puts
          puts "View the app graph:"
          puts "\e[34;4m#{resources.mermaid_url}\e[0m"
        end
      end
    end
  end
end
