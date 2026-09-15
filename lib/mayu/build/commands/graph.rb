#!/usr/bin/env ruby -rbundler/setup
# frozen_string_literal: true

require "klenod/build/cli"
require "open3"
require_relative "../../klenod"

module Mayu
  module Build
    module Commands
      class Graph < ::Klenod::Build::CLI::Graph
        class GraphvizUnavailableError < StandardError
        end

        self.description = ::Klenod::Build::CLI::Graph.description.gsub(
          "Klenod",
          "Mayu"
        )

        # Its stdout is consumed by another program.
        def self.quiet? = true

        options do
          option "--svg", "Render the graph as SVG using Graphviz."
        end

        one :bundle_path, "Path to a Mayu runtime bundle.", default: Klenod::BUNDLE_FILENAME

        def call
          bundle = ::Klenod::Runtime.load_bundle(bundle_path)
          dot =
            ::Klenod::Build::Graphviz.call(
              bundle,
              include_assets: !options[:no_assets],
              include_internal_virtual_modules: options[:internal_virtual_modules]
            )
          output.write(options[:svg] ? render_svg(dot) : dot)
        rescue GraphvizUnavailableError => error
          output.puts error.message
          1
        end

        private

        def render_svg(dot)
          svg, error, status = Open3.capture3("dot", "-Tsvg", stdin_data: dot)
          return svg if status.success?

          raise GraphvizUnavailableError, "Graphviz could not generate an SVG: #{error.strip}"
        rescue Errno::ENOENT
          raise GraphvizUnavailableError, "Graphviz is required to generate an SVG. Install the dot command and try again."
        end
      end
    end
  end
end
