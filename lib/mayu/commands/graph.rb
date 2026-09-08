#!/usr/bin/env ruby -rbundler/setup
# frozen_string_literal: true

require "klenod/build/cli"

module Mayu
  module Commands
    class Graph < ::Klenod::Build::CLI::Graph
      self.description = ::Klenod::Build::CLI::Graph.description.gsub(
        "Klenod",
        "Mayu"
      )
    end
  end
end
